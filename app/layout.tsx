import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = { title: "هملی", description: "ارتباط ساده سالمند و خانواده" };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="fa" dir="rtl"><body>{children}</body></html>;
}
