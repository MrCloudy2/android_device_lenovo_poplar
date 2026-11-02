# SELinux

- `vendor/stock/`: generated from the stock TB311XU vendor policy
  (`/vendor/etc/selinux`, firmware 37.350.260708W). It holds every type, rule and
  context that `device/mediatek/sepolicy_vndr` does not already provide. Don't edit
  it by hand. Regenerate it after a firmware or sepolicy_vndr update:

      python3 sepolicy/gen_stock_port.py <stock vendor>/etc/selinux sepolicy/vendor/stock \
          --vndr device/mediatek/sepolicy_vndr \
          --decl system/sepolicy/public --decl system/sepolicy/vendor \
          --decl system/sepolicy/private \
          --decl device/lineage/sepolicy/libperfmgr \
          --decl device/generic/trusty/custom_vm/sepolicy

  The stock `mtk_hal_audio` and `mtk_hal_sensors` domains are folded into
  `hal_audio_default` and `hal_sensors_default`, as on clove.
- `vendor/`: hand-written additions.
