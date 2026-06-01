import type { Metadata } from "next";
import ArchipelLive from "@/components/monitor/ArchipelLive";

export const metadata: Metadata = {
  title: "Archipel Live — Factory Monitor",
  description: "Real-time Archipel Software Factory dashboard",
};

export default function MonitorPage() {
  return <ArchipelLive />;
}
