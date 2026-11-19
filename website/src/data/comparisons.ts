export interface Comparison {
	slug: string;
	competitor: string;
	/** One-line summary used on the overview page and as the meta description. */
	summary: string;
	intro: string;
	sections: { heading: string; paragraphs: string[] }[];
	competitorWins: string[];
	betterCaptureWins: string[];
	chooseCompetitor: string;
	chooseBetterCapture: string;
	sources: { label: string; url: string }[];
}

/** Month the competitor facts were last checked against their official sites. */
export const lastChecked = 'November 2026';

// Competitor facts come from each vendor's official site (see `sources`).
// Re-check them before changing this file.
export const comparisons: Comparison[] = [
	{
		slug: 'quicktime',
		competitor: 'QuickTime',
		summary: 'Built into every Mac and good for quick recordings, but Apple documents only microphone audio and gives you no codec choice.',
		intro: "QuickTime Player and the Screenshot toolbar (Shift-Command-5) are already on your Mac. For a quick recording they're often all you need. BetterCapture is for when you need system audio or a specific codec.",
		sections: [
			{
				heading: 'Recording and audio',
				paragraphs: [
					'Both record the full screen, a window, or a selected area, and both can show the mouse pointer. Apple\'s toolbar also has a timer that delays the start of a recording.',
					"Apple's documentation lists a microphone as the only audio source. BetterCapture records system audio and your microphone together, with no extra audio drivers."
				]
			},
			{
				heading: 'Video quality and formats',
				paragraphs: [
					"Apple's tool saves .mov files and offers an HDR or SDR capture format, but no codec choice. BetterCapture lets you pick ProRes 422, ProRes 4444 with an alpha channel, HEVC, or H.264, in MOV or MP4, plus frame rate and quality."
				]
			},
			{
				heading: 'Editing',
				paragraphs: [
					"QuickTime Player can trim a movie (Edit > Trim). BetterCapture has no editing at all, so you'll need another app to cut your recording."
				]
			}
		],
		competitorWins: [
			'Already installed, with nothing to download',
			'Timer before the recording starts',
			'Basic trimming in QuickTime Player'
		],
		betterCaptureWins: [
			'System audio and microphone together',
			'ProRes 422, ProRes 4444 with alpha, HEVC, or H.264',
			'Hide the wallpaper, Dock, menu bar, or window shadows from recordings',
			'Menu bar app with global keyboard shortcuts and a URL scheme for automation'
		],
		chooseCompetitor: "you only need the occasional recording with microphone audio and don't care about the codec.",
		chooseBetterCapture: 'you need system audio, a professional codec, or transparent recordings, and still want a free, native app.',
		sources: [
			{ label: 'Apple: Take a screenshot or screen recording on Mac', url: 'https://support.apple.com/guide/mac-help/take-a-screenshot-or-screen-recording-mh26782/mac' },
			{ label: 'Apple: Record your screen in QuickTime Player', url: 'https://support.apple.com/guide/quicktime-player/record-your-screen-qtp97b08e666/mac' },
			{ label: 'Apple: Trim a movie or clip in QuickTime Player', url: 'https://support.apple.com/guide/quicktime-player/trim-a-movie-or-clip-qtpf2115f6fd/mac' }
		]
	},
	{
		slug: 'obs',
		competitor: 'OBS Studio',
		summary: 'Both are free and open source. OBS is a full production and streaming studio; BetterCapture is a focused, native recorder.',
		intro: 'OBS Studio and BetterCapture are both free and open source, but they solve different problems. OBS is a production studio for streaming and complex recordings. BetterCapture is a native menu bar app that does one thing: record your screen.',
		sections: [
			{
				heading: 'Recording and audio',
				paragraphs: [
					'OBS builds recordings from scenes and sources: multiple screens, webcams, images, and text, arranged freely. On macOS 13 or later (OBS 30+), it can capture all desktop audio or just one app.',
					'BetterCapture uses the native macOS content picker or an area selection. It records system audio and your microphone, and adds your camera through macOS Presenter Overlay. There are no scenes or layouts to set up, and no per-app audio capture.'
				]
			},
			{
				heading: 'Video quality and formats',
				paragraphs: [
					'Both support H.264, HEVC, and ProRes on the Mac. OBS has many more encoder settings and containers. BetterCapture keeps it to a few choices, including ProRes 4444 with an alpha channel.'
				]
			},
			{
				heading: 'Platforms and extensibility',
				paragraphs: [
					'OBS runs on Windows, macOS, and Linux, streams to all major platforms, and supports plugins, VST audio plugins, and Lua or Python scripts. BetterCapture is macOS only, cannot stream, and has no plugin system.'
				]
			}
		],
		competitorWins: [
			'Live streaming',
			'Scenes that combine multiple sources, overlays, and webcams',
			'Per-app audio capture',
			'Windows, macOS, and Linux',
			'Plugins and scripting'
		],
		betterCaptureWins: [
			'Native macOS interface that lives in the menu bar',
			'Start recording in a few clicks, with no scene setup',
			'ProRes 4444 with alpha channel out of the box',
			'Hide the wallpaper, Dock, menu bar, or window shadows from recordings'
		],
		chooseCompetitor: 'you stream, need to combine multiple sources in one recording, or work across operating systems.',
		chooseBetterCapture: 'you just want to record your Mac screen quickly with a native app and no setup.',
		sources: [
			{ label: 'OBS Studio', url: 'https://obsproject.com' },
			{ label: 'OBS: macOS desktop audio capture guide', url: 'https://obsproject.com/kb/macos-desktop-audio-capture-guide' },
			{ label: 'OBS: Audio/video formats guide', url: 'https://obsproject.com/kb/audio-video-formats-guide' },
			{ label: 'OBS Studio on GitHub', url: 'https://github.com/obsproject/obs-studio' }
		]
	},
	{
		slug: 'cleanshot-x',
		competitor: 'CleanShot X',
		summary: 'CleanShot X is a paid all-in-one screenshot and recording tool with many extras. BetterCapture is free and focused on high-quality recording.',
		intro: "CleanShot X is a polished, paid tool for screenshots and screen recordings, with lots of extras. BetterCapture doesn't take screenshots and has fewer recording extras, but it's free and offers professional codecs.",
		sections: [
			{
				heading: 'Recording and audio',
				paragraphs: [
					'Both record system audio and your microphone together. CleanShot X adds a webcam bubble you can position and resize, highlights mouse clicks, shows keystrokes, hides desktop icons, and turns on Do Not Disturb while recording.',
					"BetterCapture can add your camera through macOS Presenter Overlay and hide the wallpaper, Dock, and menu bar, but it doesn't highlight clicks or show keystrokes."
				]
			},
			{
				heading: 'Video quality and formats',
				paragraphs: [
					'CleanShot X records MP4 (H.264) or GIF. BetterCapture records ProRes 422, ProRes 4444 with alpha, HEVC, or H.264, but not GIF.'
				]
			},
			{
				heading: 'Editing, sharing, and screenshots',
				paragraphs: [
					"CleanShot X includes a video editor with smart zooms, one-click share links through its cloud, and a full screenshot toolkit with annotations, scrolling capture, and on-device text recognition (OCR). BetterCapture has none of these."
				]
			},
			{
				heading: 'Pricing',
				paragraphs: [
					'CleanShot X Basic costs $35 once, with one year of updates and optional renewal at $19 per year. CleanShot Pro, with unlimited cloud storage and team features, costs $10 per user per month billed annually. BetterCapture is free and MIT licensed.'
				]
			}
		],
		competitorWins: [
			'Screenshots, annotations, scrolling capture, and OCR',
			'Click highlighting and keystroke display',
			'Webcam bubble',
			'Video editor with smart zooms',
			'GIF recording and one-click cloud sharing'
		],
		betterCaptureWins: [
			'Free and open source',
			'ProRes 422, ProRes 4444 with alpha, and HEVC',
			'No account or cloud, so recordings stay on your Mac'
		],
		chooseCompetitor: 'you want one tool for screenshots and recordings, with annotations, click highlights, and quick sharing.',
		chooseBetterCapture: 'you mainly record video, want professional codecs, and prefer a free, open-source app.',
		sources: [
			{ label: 'CleanShot X features', url: 'https://cleanshot.com/features' },
			{ label: 'CleanShot X screen recording', url: 'https://cleanshot.com/screen-recording' },
			{ label: 'CleanShot X pricing', url: 'https://cleanshot.com/pricing' }
		]
	},
	{
		slug: 'screen-studio',
		competitor: 'Screen Studio',
		summary: 'Screen Studio turns recordings into polished demos with automatic zoom and effects. BetterCapture records clean, free source footage.',
		intro: "Screen Studio is built for polished product demos: it records your screen and then makes it look good automatically. BetterCapture doesn't edit or add effects. It records high-quality footage for free that you can edit anywhere.",
		sections: [
			{
				heading: 'Recording and audio',
				paragraphs: [
					'Both record your screen with system audio and microphone. Screen Studio also records your webcam with face tracking and background removal, shows the keys you press, and records an iPhone or iPad over USB.',
					'BetterCapture can add your camera through macOS Presenter Overlay, but has no face tracking, keystroke display, or iOS recording.'
				]
			},
			{
				heading: 'Editing and effects',
				paragraphs: [
					"This is Screen Studio's strength. It zooms in automatically on where you clicked, smooths cursor movement, and adds motion blur. BetterCapture has no editor or effects."
				]
			},
			{
				heading: 'Video quality and formats',
				paragraphs: [
					'Screen Studio exports MP4 in 720p, 1080p, or 4K at up to 60 fps, or GIFs up to 1080p, and can share a link. BetterCapture saves ProRes 422, ProRes 4444 with alpha, HEVC, or H.264 directly, which suits editing in apps like Final Cut Pro or DaVinci Resolve.'
				]
			},
			{
				heading: 'Pricing',
				paragraphs: [
					'Screen Studio is subscription only: $9 per month billed yearly, or $29 per month billed monthly, with no free plan. BetterCapture is free and MIT licensed.'
				]
			}
		],
		competitorWins: [
			'Automatic zoom, cursor smoothing, and motion blur',
			'Webcam with face tracking and background removal',
			'Keystroke display and iPhone/iPad recording',
			'GIF export and shareable links'
		],
		betterCaptureWins: [
			'Free, with no subscription',
			'ProRes and HEVC source files for professional editing',
			'Alpha channel recording with ProRes 4444',
			'Open source, with recordings that stay on your Mac'
		],
		chooseCompetitor: 'you make product demos or tutorials and want them to look polished without manual editing.',
		chooseBetterCapture: 'you want clean, high-quality recordings to edit yourself, or a free recorder for everyday use.',
		sources: [
			{ label: 'Screen Studio', url: 'https://screen.studio' },
			{ label: 'Screen Studio pricing', url: 'https://screen.studio/pricing' }
		]
	}
];
