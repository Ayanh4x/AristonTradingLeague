import "./globals.css";import SiteHeader from "@/components/SiteHeader";import Footer from "@/components/Footer";
export const metadata={title:"Ariston Trading League",description:"Structured demo trading tournaments and verified final results."};
export default function RootLayout({children}:{children:React.ReactNode}){return <><SiteHeader/><main>{children}</main><Footer/></>}