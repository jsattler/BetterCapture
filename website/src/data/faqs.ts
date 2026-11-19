export interface FAQ {
	question: string;
	answer: string;
}

/** Rendered on the page and emitted as FAQPage JSON-LD, so both stay in sync. */
export const faqs: FAQ[] = [
	{
		question: "Is BetterCapture really free?",
		answer: "Yes, BetterCapture is 100% free and open source under the MIT license. There are no subscriptions, trials, premium tiers, or hidden costs."
	},
	{
		question: "Can BetterCapture record system audio on Mac?",
		answer: "Yes, BetterCapture can record system audio and microphone simultaneously using macOS ScreenCaptureKit, without requiring any additional audio drivers or plugins."
	},
	{
		question: "What video formats does BetterCapture support?",
		answer: "BetterCapture supports ProRes 422, ProRes 4444, HEVC (H.265), and H.264 codecs. ProRes 4444 also includes alpha channel support for transparent recordings."
	},
	{
		question: "Does BetterCapture add a watermark to recordings?",
		answer: "No, BetterCapture never adds watermarks to your recordings. All recordings are clean and professional, completely free of any branding or limitations."
	},
	{
		question: "What macOS version do I need to run BetterCapture?",
		answer: "BetterCapture requires macOS 15.2 Sequoia or later. It is built with SwiftUI and ScreenCaptureKit, which require modern macOS versions for optimal performance."
	},
	{
		question: "Does BetterCapture collect any data or track usage?",
		answer: "No. BetterCapture has zero tracking, zero analytics, and zero cloud uploads. All recordings are stored locally on your Mac. No account is required, and the source code is open for anyone to verify."
	},
	{
		question: "How do I install BetterCapture?",
		answer: "Install it with Homebrew by running \"brew install bettercapture\", or download BetterCapture.dmg from the latest GitHub release."
	}
];
