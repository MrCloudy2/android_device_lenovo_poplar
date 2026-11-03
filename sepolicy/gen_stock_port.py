#!/usr/bin/env python3
"""Port the stock vendor SELinux policy (vendor_sepolicy.cil + contexts) into
device-tree .te / context files, the way the clove tree's stock_port.te was made:

  * platform types are referenced as <name>_<ver> in vendor CIL: strip the suffix
  * skip anything sepolicy_vndr (or the AOSP/Lineage trees given with --decl)
    already declares, so nothing is declared twice
  * neverallow / roletype / base_typeattr_* expansions are dropped
  * stock domains that LineageOS replaces with its own build are folded into the
    AOSP default domain (MERGE below)

usage: gen_sepolicy_port.py <stock selinux dir> <out dir> --decl DIR [--decl DIR ...]
"""
import argparse, os, re, sys
from collections import OrderedDict

# Stock domain -> domain LineageOS uses for the same binary (clove did the same).
# Stock rules that violate Android 17 neverallows: (regex, replacement or None to drop).
NEVERALLOW_FIXUPS = [
    # app_neverallows: sepolicy_vndr declares gpuserv protected_service, so untrusted
    # apps may not find it; drop stock's "app-safe" tag
    (r'^typeattribute mtk_hal_gpuserv_service mtk_safe_service_manager_type;$', None),
    # native_app_zygote (private, unnameable here) may only find an allowlist of
    # services: split stock's "every domain" grant into vendor domains, apps and
    # the core graphics users
    (r'^allow \{ domain -isolated_app_all .* \} (mtk_hal_mali_platform_default_service:service_manager \{ find \};)$',
     r'allow { domain -coredomain -hal_configstore_server -vendor_init } \1\n'
     r'allow { appdomain -isolated_app_all } \1\n'
     r'allow { surfaceflinger system_server cameraserver mediaserver bootanim mediaswcodec } \1'),
    # system_server may not load kernel modules
    (r'^allow system_server self:capability \{ sys_module \};$', None),
    # sepolicy_vndr mtk_hal_netdagent.te neverallow
    (r'^allow mtk_hal_power mtk_hal_netdagent_service:service_manager', None),
    # domain.te: binder/fd only between processes; service labels are not domains
    (r'^allow (appdomain mtk_safe_service_manager_type:(binder|fd)|mtk_safe_service_manager_type appdomain:binder) ', None),
    # sepolicy_test: isolated (sandboxed) apps get no extra grants
    (r'^allow isolated_compute_app ', None),
    # domain.te: ioctl on non-device files needs an xperm allowlist
    (r'^(allow (?:smartplatformserver sysfs_mmcblk|vendor_lenovo_battery_default persist_vendor_file):(?:dir|file) \{) ioctl ',
     r'\1 '),
]

MERGE = {
    'mtk_hal_audio': 'hal_audio_default',
    'mtk_hal_audio_exec': 'hal_audio_default_exec',
    'mtk_hal_sensors': 'hal_sensors_default',
    'mtk_hal_sensors_exec': 'hal_sensors_default_exec',
}

DECL_MACROS = {
    # macro -> list of name templates it declares
    'hal_attribute': ['hal_{0}', 'hal_{0}_client', 'hal_{0}_server'],
    'type': ['{0}'],
}
PROP_MACROS = ('vendor_restricted_prop', 'vendor_internal_prop', 'vendor_public_prop',
               'system_internal_prop', 'system_restricted_prop', 'system_public_prop',
               'system_vendor_config_prop', 'vendor_vendor_config_prop')


def strip_m4_comments(s):
    return re.sub(r'#[^\n]*', '', s)


def collect_declared(dirs):
    """Types and attributes declared by .te/macro files under dirs."""
    declared = set()
    for d in dirs:
        for root, _, files in os.walk(d):
            if '/.git' in root:
                continue
            for f in files:
                if not (f.endswith('.te') or f in ('attributes', 'global_macros', 'te_macros')):
                    continue
                s = strip_m4_comments(open(os.path.join(root, f), errors='replace').read())
                for m in re.finditer(r'^\s*(type|attribute)\s+([A-Za-z0-9_.-]+)', s, re.M):
                    declared.add(m.group(2))
                for m in re.finditer(r'^\s*typealias\s+\S+\s+alias\s+(\{[^}]*\}|\S+)', s, re.M):
                    declared.update(re.findall(r'[A-Za-z0-9_.-]+', m.group(1)))
                for m in re.finditer(r'\bhal_attribute\(\s*([A-Za-z0-9_.-]+)\s*\)', s):
                    n = m.group(1)
                    declared.update({'hal_' + n, 'hal_%s_client' % n, 'hal_%s_server' % n})
                # app_domain()/userfaultfd_use() declare <domain>_userfaultfd
                for m in re.finditer(r'\b(?:app_domain|userfaultfd_use)\(\s*([A-Za-z0-9_.-]+)\s*\)', s):
                    declared.add(m.group(1) + '_userfaultfd')
                for mac in PROP_MACROS:
                    for m in re.finditer(r'\b%s\(\s*([A-Za-z0-9_.-]+)\s*\)' % mac, s):
                        declared.add(m.group(1))
    return declared


def sexp_tokens(s):
    return re.findall(r'\(|\)|"[^"]*"|[^\s()]+', s)


def parse_sexps(s):
    toks = sexp_tokens(s)
    stack, out = [[]], None
    for t in toks:
        if t == '(':
            stack.append([])
        elif t == ')':
            e = stack.pop()
            stack[-1].append(e)
        else:
            stack[-1].append(t)
    return stack[0]


class Porter:
    def __init__(self, ver, declared):
        self.ver = ver
        self.suffix = '_' + ver
        self.declared = declared
        self.vendor_types = set()
        self.vendor_attrs = set()

    def n(self, name):
        """Normalize one type/attribute name."""
        if name.startswith('base_typeattr_'):
            return self.bta[name]
        if name.endswith(self.suffix):
            name = name[:-len(self.suffix)]
        return MERGE.get(name, name)

    def is_platform(self, name):
        return name.endswith(self.suffix)

    def names(self, x):
        if isinstance(x, list):
            if x and x[0] in ('and', 'or', 'not', 'all'):
                return None  # expression: not portable as-is
            return [self.n(i) for i in x]
        return [self.n(x)]

    def te_set(self, items):
        items = list(OrderedDict.fromkeys(items))
        if len(items) > 1 and any(i.startswith('~') for i in items):
            raise ValueError('complement inside a set: %r' % items)
        if len(items) > 1 and any(i.startswith('{') for i in items):
            items = [w for i in items for w in i.strip('{} ').split()]
        return items[0] if len(items) == 1 else '{ %s }' % ' '.join(items)

    @staticmethod
    def xperm(spec):
        out = []
        for i in spec:
            if isinstance(i, list) and i and i[0] == 'range':
                out.append('%s-%s' % (i[1], i[2]))
            elif isinstance(i, list):
                out.extend(Porter.xperm(i))
            else:
                out.append(i)
        return out

    def expr(self, e):
        """CIL attribute expression -> te set body (without braces)."""
        flat = lambda l: [self.n(x) for x in (l if isinstance(l, list) else [l])]
        if e and e[0] == 'and' and len(e) == 3 and isinstance(e[2], list) and e[2][:1] == ['not']:
            return flat(e[1]) + ['-' + x for x in flat(e[2][1])]
        if e and e[0] == 'or':
            return [x for part in e[1:] for x in flat(part)]
        if e and e[0] == 'not' and len(e) == 2:
            return ['~{ %s }' % ' '.join(flat(e[1]))]
        if e and e[0] in ('and', 'not', 'all'):
            raise ValueError('unsupported attribute expression: %r' % (e,))
        return flat(e)

    def port(self, cil):
        sx = parse_sexps(cil)
        # base_typeattr_N: compiler-generated expansions, referenced by rules.
        raw = {e[1]: e[2] for e in sx if isinstance(e, list) and len(e) == 3
               and e[0] == 'typeattributeset' and e[1].startswith('base_typeattr_')}
        self.bta = {}
        for k, v in raw.items():
            self.bta[k] = None  # placeholder; filled lazily below
        for k, v in raw.items():
            x = self.expr(v)
            self.bta[k] = x[0] if len(x) == 1 and x[0].startswith('~') else '{ %s }' % ' '.join(x)
        decls, attrs, ta, rules, skipped = [], [], [], [], []
        for e in sx:
            if not isinstance(e, list) or not e:
                continue
            k = e[0]
            if k == 'type':
                t = self.n(e[1])
                self.vendor_types.add(t)
                if t not in self.declared and e[1] not in MERGE:
                    decls.append('type %s;' % t)
            elif k == 'typeattribute':
                a = e[1]
                if a.startswith('base_typeattr_') or self.is_platform(a):
                    continue
                self.vendor_attrs.add(a)
                if a not in self.declared:
                    attrs.append('attribute %s;' % a)
            elif k == 'typealias':
                pass
            elif k == 'typealiasactual':
                if e[1] not in self.declared:
                    ta.append('typealias %s alias %s;' % (self.n(e[2]), e[1]))
            elif k == 'typeattributeset':
                a = e[1]
                if a.startswith('base_typeattr_') or self.is_platform(a):
                    continue  # neverallow expansions / version mapping
                mem = e[2]
                if isinstance(mem, list) and mem and mem[0] in ('and', 'or', 'not', 'all'):
                    skipped.append(a)
                    continue
                for m in mem:
                    if self.is_platform(m) or m.startswith('base_typeattr_'):
                        continue  # platform side: mapping file already does this
                    ta.append('typeattribute %s %s;' % (self.n(m), a))
            elif k in ('allow', 'dontaudit', 'auditallow'):
                src, tgt, (cls, perms) = self.names(e[1]), self.names(e[2]), e[3]
                if src is None or tgt is None:
                    skipped.append(' '.join(map(str, e)))
                    continue
                perms = perms if isinstance(perms, list) else [perms]
                rules.append('%s %s %s:%s { %s };' % (k, self.te_set(src), self.te_set(tgt), cls, ' '.join(perms)))
            elif k == 'allowx':
                src, tgt = self.names(e[1]), self.names(e[2])
                op, cls, spec = e[3]
                rules.append('allowxperm %s %s:%s %s { %s };' % (self.te_set(src), self.te_set(tgt), cls, op,
                                                               ' '.join(self.xperm(spec))))
            elif k == 'typetransition':
                if len(e) == 6:
                    s, t, c, nm, r = e[1:]
                    if self.n(r).endswith('_userfaultfd') and self.n(r) in self.declared:
                        continue  # macro elsewhere (userfaultfd_use) already has it
                    rules.append('type_transition %s %s:%s %s %s;' % (self.n(s), self.n(t), c, self.n(r), nm))
                else:
                    s, t, c, r = e[1:]
                    rules.append('type_transition %s %s:%s %s;' % (self.n(s), self.n(t), c, self.n(r)))
            elif k in ('neverallow', 'neverallowx', 'roletype', 'genfscon'):
                pass
            else:
                skipped.append(k)
        # self-referencing merged rules (e.g. hal_audio_default -> itself) are fine
        ta = list(OrderedDict.fromkeys(x for x in ta if x.split()[1] != x.split()[2].rstrip(';')))
        rules = list(OrderedDict.fromkeys(rules))
        return decls, attrs, ta, rules, skipped


def port_genfs(cil, ver):
    out = []
    for e in parse_sexps(cil):
        if isinstance(e, list) and e and e[0] == 'genfscon':
            fs, path, ctx = e[1], e[2], e[3]
            # ctx = [u, object_r, type, [[s0]...]] or a named context
            t = ctx[2] if isinstance(ctx, list) else ctx
            if t.endswith('_' + ver):
                continue  # platform-labelled: the platform policy already has it
            out.append('genfscon %s %s u:object_r:%s:s0' % (fs, path, MERGE.get(t, t)))
    return out


def ctx_lines(path):
    out = []
    for l in open(path, errors='replace'):
        l = l.strip()
        if l and not l.startswith('#'):
            out.append(l)
    return out


def port_contexts(stock, vndr_files, declared_types, keyfn):
    """Stock context lines whose key is not already in sepolicy_vndr."""
    have = set()
    for f in vndr_files:
        if os.path.exists(f):
            have.update(keyfn(l) for l in ctx_lines(f))
    out = []
    for l in ctx_lines(stock):
        if keyfn(l) in have:
            continue
        for k, v in MERGE.items():
            l = re.sub(r':%s:' % k, ':%s:' % v, l)
        out.append(l)
    return out


def drop_private(lines, priv):
    """Remove private names from te statements; drop a statement when a
    source/target/type position would be left empty."""
    tok = re.compile(r'(?<![\w.-])(-?)([A-Za-z0-9_.-]+)(?![\w.-])')
    out, trimmed, dropped = [], 0, 0
    for l in lines:
        if l == '#SPLIT' or not any(n in priv for n in re.findall(r'[A-Za-z0-9_.-]+', l)):
            out.append(l)
            continue
        head, _, tail = l.partition(':') if not l.startswith(('typeattribute', 'typealias')) else (l, '', '')
        words = head.split(None, 1)
        kw, body = words[0], words[1] if len(words) > 1 else ''
        if kw in ('typeattribute', 'typealias', 'type_transition') or not tail:
            dropped += 1
            continue
        # body = "SRC TGT" where each is a name or a { } / ~{ } set
        parts = re.findall(r'~?\{[^}]*\}|\S+', body)
        newparts = []
        for part in parts:
            if part.lstrip('~').startswith('{'):
                inner = [w for w in part.lstrip('~').strip('{} ').split() if w.lstrip('-') not in priv]
                if not [w for w in inner if not w.startswith('-')]:
                    newparts = None
                    break
                newparts.append(('~' if part.startswith('~') else '') + '{ %s }' % ' '.join(inner))
            elif part in priv:
                newparts = None
                break
            else:
                newparts.append(part)
        # perms/class side (tail) never holds type names except in type_transition
        if newparts is None or len(newparts) != len(parts):
            dropped += 1
            continue
        trimmed += 1
        out.append('%s %s:%s' % (kw, ' '.join(newparts), tail))
    return out, trimmed, dropped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('stock')
    ap.add_argument('out')
    ap.add_argument('--decl', action='append', default=[], help='policy dirs whose declarations to skip')
    ap.add_argument('--vndr', required=True, help='sepolicy_vndr checkout (contexts dedup)')
    ap.add_argument('--private', action='append', default=[],
                    help='platform/system_ext private policy dirs: names declared only there are '
                         'invisible to vendor policy, so rules using them are trimmed')
    ap.add_argument('--genfs-cil', action='append', default=[],
                    help='platform compat genfs CIL (plat_sepolicy_genfs_<level>.cil) to dedup against')
    ap.add_argument('--base-conf', help='m4-expanded vendor policy without this port: '
                    'type_transitions it already has are dropped')
    a = ap.parse_args()

    ver = open(os.path.join(a.stock, 'plat_sepolicy_vers.txt')).read().strip()
    cil = open(os.path.join(a.stock, 'vendor_sepolicy.cil')).read()
    declared = collect_declared(a.decl + [a.vndr])
    p = Porter(ver, declared)
    decls, attrs, ta, rules, skipped = p.port(cil)
    priv = collect_declared(a.private) - collect_declared(a.decl)
    # Stock platform (system-side, versioned) domains LineageOS does not have, e.g.
    # Lenovo's smartplatformserver: rules for them are dead, and declaring them
    # here would give vendor policy a non-domain type used with binder.
    m = re.search(r'^\(typeattributeset domain \(([^)]*)\)', cil, re.M)
    plat_domains = {x[:-len(ver) - 1] for x in m.group(1).split() if x.endswith('_' + ver)} if m else set()
    dead = plat_domains - collect_declared(a.decl + a.private)
    sys.stderr.write('dead platform domains: %s\n' % ' '.join(sorted(dead)))
    priv |= dead
    for pat, rep in NEVERALLOW_FIXUPS:
        hit = [l for l in ta + rules if re.search(pat, l)]
        if not hit:
            sys.stderr.write('warning: neverallow fixup matched nothing: %s\n' % pat)
        if rep is None:
            ta = [l for l in ta if not re.search(pat, l)]
            rules = [l for l in rules if not re.search(pat, l)]
        else:
            ta = [re.sub(pat, rep, l) for l in ta]
            rules = [re.sub(pat, rep, l) for l in rules]
    ta, trimmed, dropped = drop_private(ta + ['#SPLIT'] + rules, priv)
    i = ta.index('#SPLIT'); ta, rules = ta[:i], ta[i + 1:]
    if a.base_conf:
        key = lambda l: re.sub(r'\s+', ' ', re.sub(r'^type_transition (\S+ \S+:\S+) \S+', r'\1', l.strip()))
        base = {key(l) for l in open(a.base_conf, errors='replace') if l.lstrip().startswith('type_transition ')}
        n0 = len(rules)
        rules = [r for r in rules if not (r.startswith('type_transition ') and key(r) in base)]
        sys.stderr.write('type_transitions already in base: %d\n' % (n0 - len(rules)))
    sys.stderr.write('private names: %d, rules trimmed %d, dropped %d\n' % (len(priv), trimmed, dropped))
    # MTK's system_ext public policy (in the stock plat_pub_versioned.cil,
    # unversioned names) is only partly in sepolicy_vndr: declare the rest here.
    pub = open(os.path.join(a.stock, 'plat_pub_versioned.cil')).read()
    used = '\n'.join(ta + rules)
    for kind, kw in (('typeattribute', 'attribute'), ('type', 'type')):
        for name in re.findall(r'^\(%s ([^\s()]+)\)' % kind, pub, re.M):
            if name.endswith('_' + ver) or name.startswith('base_typeattr_') or name in declared:
                continue
            if re.search(r'(?<![\w-])%s(?![\w-])' % re.escape(name), used):
                (attrs if kw == 'attribute' else decls).append('%s %s;' % (kw, name))
    attrs = list(OrderedDict.fromkeys(attrs)); decls = list(OrderedDict.fromkeys(decls))
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, 'stock_port.te'), 'w') as f:
        f.write('# Ported from the stock TB311XU vendor policy (vendor_sepolicy.cil,\n'
                '# firmware 37.350.260708W) by sepolicy/gen_stock_port.py. Do not edit by hand.\n\n')
        for blk in (attrs, decls, ta, rules):
            f.write('\n'.join(blk) + '\n\n')

    # dedup contexts/genfs against every policy dir in the build, not just sepolicy_vndr
    ctx_dirs = [os.path.join(a.vndr, 'base', 'vendor'), os.path.join(a.vndr, 'debug', 'vendor')] + a.decl + a.private
    vd = lambda *x: [os.path.join(d, *x) for d in ctx_dirs]
    first = lambda l: l.split()[0]
    jobs = [
        ('vendor_file_contexts', 'file_contexts', first),
        ('vendor_property_contexts', 'property_contexts', first),
        ('vendor_service_contexts', 'service_contexts', first),
        ('vendor_hwservice_contexts', 'hwservice_contexts', first),
        ('vndservice_contexts', 'vndservice_contexts', first),
    ]
    for src, dst, key in jobs:
        sp = os.path.join(a.stock, src)
        if not os.path.exists(sp):
            continue
        lines = port_contexts(sp, vd(dst), declared, key)
        with open(os.path.join(a.out, dst), 'w') as f:
            f.write('# Stock TB311XU entries not provided by sepolicy_vndr (generated)\n')
            f.write('\n'.join(lines) + '\n')
    genfs = port_genfs(cil, ver)
    gkey = lambda l: tuple(x.strip('"') for x in l.split()[1:3])
    have = set()
    for f in vd('genfs_contexts') + [os.path.join(a.vndr, 'base', 'private', 'genfs_contexts')]:
        if os.path.exists(f):
            have.update(gkey(l) for l in ctx_lines(f) if l.startswith('genfscon'))
    for f in a.genfs_cil:
        have.update(re.findall(r'^\(genfscon (\S+) "([^"]*)"', open(f).read(), re.M))
    genfs = [g for g in genfs if gkey(g) not in have]
    with open(os.path.join(a.out, 'genfs_contexts'), 'w') as f:
        f.write('# Stock TB311XU genfscon entries not provided by sepolicy_vndr (generated)\n')
        f.write('\n'.join(genfs) + '\n')

    print('attributes %d, types %d, typeattribute %d, rules %d, skipped %d, genfs %d' %
          (len(attrs), len(decls), len(ta), len(rules), len(skipped), len(genfs)), file=sys.stderr)
    if skipped:
        print('skipped (expressions/unknown):', sorted(set(map(str, skipped)))[:20], file=sys.stderr)


if __name__ == '__main__':
    main()
