type P = { size?: number; className?: string };
const base = (size: number) => ({ width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, "aria-hidden": true });

export const BranchIcon = ({ size = 28, className }: P) => (
  <svg {...base(size)} className={className}>
    <circle cx="6" cy="5.5" r="2.3" /><circle cx="6" cy="18.5" r="2.3" /><circle cx="18" cy="8.5" r="2.3" />
    <path d="M6 7.8v8.4M18 10.8c0 4-6 3-11 6.2" />
  </svg>
);
export const LogIcon = ({ size = 20, className }: P) => (
  <svg {...base(size)} className={className}><path d="M5 6h14M5 12h14M5 18h9" /><circle cx="19" cy="18" r="1.2" /></svg>
);
export const CheckIcon = ({ size = 20, className }: P) => (
  <svg {...base(size)} className={className}><circle cx="12" cy="12" r="8.5" /><path d="m8.5 12.3 2.4 2.4 4.6-5" /></svg>
);
export const LayersIcon = ({ size = 20, className }: P) => (
  <svg {...base(size)} className={className}><path d="m12 4 8.5 4.5L12 13 3.5 8.5z" /><path d="m3.5 12.5 8.5 4.5 8.5-4.5M3.5 16.5 12 21l8.5-4.5" /></svg>
);
export const ArrowIcon = ({ size = 18, className }: P) => (
  <svg {...base(size)} className={className}><path d="M5 12h14M13 6l6 6-6 6" /></svg>
);
export const ChevronIcon = ({ size = 14, className }: P) => (
  <svg {...base(size)} className={className}><path d="m9 6 6 6-6 6" /></svg>
);
export const MenuIcon = ({ size = 22, className }: P) => (
  <svg {...base(size)} className={className}><path d="M4 7h16M4 12h16M4 17h16" /></svg>
);
export const CloseIcon = ({ size = 22, className }: P) => (
  <svg {...base(size)} className={className}><path d="M6 6l12 12M18 6 6 18" /></svg>
);
export const DownloadIcon = ({ size = 16, className }: P) => (
  <svg {...base(size)} className={className}><path d="M12 4v11M7 11l5 5 5-5M5 20h14" /></svg>
);
export const ExternalIcon = ({ size = 14, className }: P) => (
  <svg {...base(size)} className={className}><path d="M14 5h5v5M19 5l-8 8M18 14v4a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h4" /></svg>
);
export const ListIcon = ({ size = 16, className }: P) => (
  <svg {...base(size)} className={className}><path d="M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01" /></svg>
);
