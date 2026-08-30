import type { Metadata } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
});

const geistMono = Geist_Mono({
  variable: '--font-geist-mono',
  subsets: ['latin'],
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? 'https://fitcalgary.invalid'),
  title: 'FitCalgary Index — The city, ranked.',
  description: 'Calgary gym discovery, transparent membership pricing, local events, and verified fitness leaderboards.',
  openGraph: {
    title: 'FitCalgary Index — The city, ranked.',
    description: 'Transparent gym pricing, local events, and video-verified fitness leaderboards.',
    type: 'website',
    images: [{ url: '/og.png', width: 1536, height: 1024, alt: 'FitCalgary Index — Calgary, measured.' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'FitCalgary Index — The city, ranked.',
    description: 'Transparent gym pricing, local events, and video-verified fitness leaderboards.',
    images: ['/og.png'],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
