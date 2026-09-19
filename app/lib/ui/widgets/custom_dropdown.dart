import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'common.dart';

/// Item opsi untuk dropdown custom XyCloudStore
class XyDropdownOption<T> {
  const XyDropdownOption({
    required this.value,
    required this.label,
    this.icon,
    this.sub,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? sub;
}

/// Dropdown custom 100% buatan sendiri tanpa komponen bawaan Flutter / Material spinner
class XyDropdown<T> extends StatelessWidget {
  const XyDropdown({
    super.key,
    this.label,
    this.hint = 'Pilih opsi…',
    required this.value,
    required this.options,
    required this.onChanged,
    this.prefixIcon,
    this.enabled = true,
    this.isDense = false,
  });

  final String? label;
  final String hint;
  final T? value;
  final List<XyDropdownOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final IconData? prefixIcon;
  final bool enabled;
  final bool isDense;

  XyDropdownOption<T>? get _selectedOption {
    try {
      return options.firstWhere((o) => o.value == value);
    } catch (_) {
      return null;
    }
  }

  void _bukaPilihan(BuildContext context) {
    if (!enabled || onChanged == null) return;
    final pal = XyTheme.of(context);

    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: pal.surfaceHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: pal.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: pal.line,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label ?? 'Pilih Opsi',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: pal.line),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (c, idx) {
                      final item = options[idx];
                      final terpilih = item.value == value;

                      return Pressable(
                        onTap: () {
                          Navigator.pop(ctx, item.value);
                          onChanged?.call(item.value);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: terpilih
                                ? XyTheme.primary.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: terpilih ? XyTheme.primary : pal.line,
                              width: terpilih ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (item.icon != null) ...[
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: terpilih
                                        ? XyTheme.primary.withOpacity(0.2)
                                        : pal.lineSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 18,
                                    color: terpilih ? XyTheme.primary : pal.inkSoft,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: terpilih
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: terpilih ? XyTheme.primary : pal.ink,
                                      ),
                                    ),
                                    if (item.sub != null && item.sub!.isNotEmpty) ...[
                                      const SizedBox(height: 2.5),
                                      Text(
                                        item.sub!,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: pal.muted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (terpilih)
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: XyTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = XyTheme.of(context);
    final selected = _selectedOption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: pal.muted,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Pressable(
          onTap: enabled ? () => _bukaPilihan(context) : null,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isDense ? 10 : 14,
            ),
            decoration: BoxDecoration(
              color: pal.surface,
              borderRadius: BorderRadius.circular(XyRadius.md),
              border: Border.all(color: pal.line),
            ),
            child: Row(
              children: [
                if (prefixIcon != null) ...[
                  Icon(prefixIcon, size: 19, color: pal.muted),
                  const SizedBox(width: 10),
                ] else if (selected?.icon != null) ...[
                  Icon(selected!.icon, size: 19, color: XyTheme.primary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    selected?.label ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected != null ? FontWeight.w600 : FontWeight.w400,
                      color: selected != null ? pal.ink : pal.muted,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: pal.muted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Selector dropdown berbentuk pill kompak untuk toolbar atau dialog
class XyPillSelector<T> extends StatelessWidget {
  const XyPillSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.title = 'Pilih Opsi',
  });

  final T value;
  final List<XyDropdownOption<T>> options;
  final ValueChanged<T> onChanged;
  final String title;

  @override
  Widget build(BuildContext context) {
    final pal = XyTheme.of(context);
    XyDropdownOption<T>? cur;
    try {
      cur = options.firstWhere((o) => o.value == value);
    } catch (_) {
      cur = options.isNotEmpty ? options.first : null;
    }

    return Pressable(
      onTap: () {
        showModalBottomSheet<T>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            decoration: BoxDecoration(
              color: pal.surfaceHigh,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: pal.line),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: pal.line,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: pal.line),
                  ...options.map((opt) {
                    final sel = opt.value == value;
                    return ListTile(
                      dense: true,
                      leading: opt.icon != null
                          ? Icon(opt.icon,
                              color: sel ? XyTheme.primary : pal.inkSoft, size: 20)
                          : null,
                      title: Text(
                        opt.label,
                        style: TextStyle(
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? XyTheme.primary : pal.ink,
                        ),
                      ),
                      subtitle: opt.sub != null ? Text(opt.sub!) : null,
                      trailing: sel
                          ? const Icon(Icons.check_rounded,
                              color: XyTheme.primary, size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onChanged(opt.value);
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: BorderRadius.circular(XyRadius.pill),
          border: Border.all(color: pal.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cur?.icon != null) ...[
              Icon(cur!.icon, size: 14, color: XyTheme.primary),
              const SizedBox(width: 5),
            ],
            Text(
              cur?.label ?? '',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pal.ink,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: pal.muted),
          ],
        ),
      ),
    );
  }
}
