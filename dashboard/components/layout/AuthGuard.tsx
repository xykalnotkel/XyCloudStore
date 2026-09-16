"use client";
import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";

function getKey(): string {
  if (typeof window === "undefined") return "";
  return sessionStorage.getItem("xy_admin_key") || "";
}

export default function AuthGuard({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [mounted, setMounted] = useState(false);
  const [checked, setChecked] = useState(false);

  // Hanya halaman login yang publik; dashboard root tetap dilindungi.
  const isPublic = pathname === "/login" || pathname === "/login/";

  useEffect(() => {
    setMounted(true);
    if (isPublic) {
      setChecked(true);
      return;
    }
    const k = getKey();
    if (!k) {
      router.replace("/login");
    } else {
      setChecked(true);
    }
  }, [pathname, router, isPublic]);

  if (isPublic) {
    return <>{children}</>;
  }

  // avoid hydration mismatch: render same spinner on server and first client render
  if (!mounted || !checked) {
    return (
      <div className="min-h-[60vh] grid place-items-center">
        <div className="flex flex-col items-center gap-3">
          <div className="w-8 h-8 rounded-full border-2 border-[#E9E3F5] border-t-[#7C3AED] animate-spin" />
          <div className="text-[13px] text-[#7C738F] font-medium">Memeriksa sesi admin...</div>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}
