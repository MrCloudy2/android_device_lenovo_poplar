# SELinux

- `vendor/stock/`: generated from the stock TB311XU vendor policy
  (`/vendor/etc/selinux`, firmware 37.350.260708W). It holds every type, rule and
  context that the rest of the build does not already provide. Don't edit it by
  hand. Regenerate it after a firmware, sepolicy_vndr or platform policy update.
  Run this from the top of the tree:

      # 1. the vendor policy without this port, for type_transition dedup
      : > device/lenovo/poplar/sepolicy/vendor/stock/stock_port.te
      m vendor_sepolicy.conf
      cp out/soong/.intermediates/system/sepolicy/vendor_sepolicy.conf/android_common/poplar/vendor_sepolicy.conf /tmp/base.conf

      # 2. generate
      python3 device/lenovo/poplar/sepolicy/gen_stock_port.py <stock vendor>/etc/selinux \
          device/lenovo/poplar/sepolicy/vendor/stock \
          --vndr device/mediatek/sepolicy_vndr \
          --decl system/sepolicy/flagging --decl system/sepolicy/reqd_mask \
          --decl system/sepolicy/public --decl system/sepolicy/vendor \
          --decl device/mediatek/sepolicy_vndr/base/public \
          --decl device/mediatek/sepolicy_vndr/base/vendor \
          --decl device/mediatek/sepolicy_vndr/debug/public \
          --decl device/mediatek/sepolicy_vndr/debug/vendor \
          --decl device/lineage/sepolicy/common/public \
          --decl device/lineage/sepolicy/common/dynamic \
          --decl device/lineage/sepolicy/common/vendor \
          --decl device/lineage/sepolicy/libperfmgr/vendor \
          --decl device/generic/trusty/custom_vm/sepolicy \
          --private system/sepolicy/private \
          --private device/mediatek/sepolicy_vndr/base/private \
          --private device/mediatek/sepolicy_vndr/debug/private \
          --private device/lineage/sepolicy/common/private \
          --private device/generic/trusty/sepolicy/system_ext/private \
          --genfs-cil system/sepolicy/compat/plat_sepolicy_genfs_202604.cil \
          --base-conf /tmp/base.conf

      # 3. check
      m selinux_policy

  - `--decl` takes exactly the dirs that feed the vendor policy (the m4 inputs of
    `vendor_sepolicy.conf`). Types declared there are not declared again.
  - `--private` takes platform and system_ext private dirs. Vendor policy can't see
    the names they declare, so rules using those names are trimmed or dropped. The
    same goes for stock platform domains that LineageOS doesn't have
    (`smartplatformserver`, `otapreopt_chroot`).
  - `NEVERALLOW_FIXUPS` in the script lists the stock rules that are changed or
    dropped because they break Android 17 neverallows or `sepolicy_test`. One of
    them is the power HAL's `sysfs_mcupm` access, because sepolicy_vndr makes that
    type private.

  The stock `mtk_hal_audio` and `mtk_hal_sensors` domains are folded into
  `hal_audio_default` and `hal_sensors_default`, as on clove.
- `vendor/`: hand-written additions.
