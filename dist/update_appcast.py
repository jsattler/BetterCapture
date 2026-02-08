"""
Update the appcast.xml file for BetterCapture releases.

This script adds a new entry to the Sparkle appcast with the release
information, including GitHub release notes rendered as inline HTML.

The resulting appcast.xml is uploaded as a GitHub release asset so that
Sparkle clients can fetch it from a stable URL:
    https://github.com/jsattler/BetterCapture/releases/latest/download/appcast.xml

Expected files in the current directory:
    - sign_update.txt   Output from Sparkle's `sign_update` tool.
    - appcast.xml        The existing appcast file (downloaded from the
                         previous release, or a fresh template if this is
                         the first release).

Required environment variables:
    - VERSION            The version number (e.g. 1.0.0).
    - BUILD_NUMBER       The build number (typically same as VERSION).
    - DMG_URL            The download URL for the DMG.

Optional environment variables:
    - RELEASE_NOTES      The GitHub release body in markdown.
    - RELEASE_URL        The GitHub release URL.

The script outputs appcast_new.xml.
"""

import os
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

now = datetime.now(timezone.utc)
version = os.environ["VERSION"]
build_number = os.environ["BUILD_NUMBER"]
dmg_url = os.environ["DMG_URL"]
release_notes = os.environ.get("RELEASE_NOTES", "")
release_url = os.environ.get("RELEASE_URL", "")
repo_url = "https://github.com/jsattler/BetterCapture"

# Define Sparkle namespace URI for element creation
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"

# Read sign_update output (e.g. 'sparkle:edSignature="..." length="12345"')
with open("sign_update.txt", "r") as f:
    attrs = {}
    for pair in f.read().strip().split(" "):
        if "=" not in pair:
            continue
        key, value = pair.split("=", 1)
        value = value.strip().strip('"')
        # Convert sparkle: prefix to full namespace URI for ElementTree
        if key.startswith("sparkle:"):
            key = f"{{{SPARKLE_NS}}}" + key[8:]
        attrs[key] = value

# Define namespace mapping for lookups
namespaces = {"sparkle": SPARKLE_NS}

# Register namespaces so ElementTree uses correct prefixes when writing new elements
ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("dc", "http://purl.org/dc/elements/1.1/")

# Parse existing appcast or create a fresh one if missing / malformed
if os.path.exists("appcast.xml"):
    try:
        et = ET.parse("appcast.xml")
        channel = et.find("channel")
        if channel is None:
            raise ValueError("No <channel> element found")
    except Exception as exc:
        print(
            f"Warning: could not parse existing appcast.xml ({exc}), creating fresh one"
        )
        et = None
else:
    print("No existing appcast.xml found, creating fresh one")
    et = None

if et is None:
    root = ET.fromstring(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<rss version="2.0"'
        ' xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"'
        ' xmlns:dc="http://purl.org/dc/elements/1.1/">'
        "<channel>"
        "<title>BetterCapture Updates</title>"
        "<link>https://github.com/jsattler/BetterCapture/releases/latest/download/appcast.xml</link>"
        "<description>Updates for BetterCapture</description>"
        "<language>en</language>"
        "</channel>"
        "</rss>"
    )
    et = ET.ElementTree(root)
    channel = root.find("channel")

# Remove any existing items with the same version
for item in channel.findall("item"):
    sv = item.find("sparkle:shortVersionString", namespaces)
    if sv is not None and sv.text == version:
        channel.remove(item)
    # Also remove items without pubDate (malformed)
    if item.find("pubDate") is None:
        channel.remove(item)

# Prune old items, keep the most recent 15
pubdate_format = "%a, %d %b %Y %H:%M:%S %z"
items = channel.findall("item")
items_with_date = [item for item in items if item.find("pubDate") is not None]
items_with_date.sort(
    key=lambda item: datetime.strptime(item.find("pubDate").text, pubdate_format)
)
prune_limit = 15
if len(items_with_date) > prune_limit:
    for item in items_with_date[:-prune_limit]:
        channel.remove(item)


def markdown_to_simple_html(md: str) -> str:
    """Very basic markdown to HTML conversion for release notes."""
    lines = md.strip().split("\n")
    html_lines = []
    in_list = False

    for line in lines:
        stripped = line.strip()

        # Skip empty lines
        if not stripped:
            if in_list:
                html_lines.append("</ul>")
                in_list = False
            html_lines.append("")
            continue

        # Headers
        if stripped.startswith("### "):
            if in_list:
                html_lines.append("</ul>")
                in_list = False
            html_lines.append(f"<h4>{stripped[4:]}</h4>")
        elif stripped.startswith("## "):
            if in_list:
                html_lines.append("</ul>")
                in_list = False
            html_lines.append(f"<h3>{stripped[3:]}</h3>")
        elif stripped.startswith("# "):
            if in_list:
                html_lines.append("</ul>")
                in_list = False
            html_lines.append(f"<h2>{stripped[2:]}</h2>")
        # List items
        elif stripped.startswith("- ") or stripped.startswith("* "):
            if not in_list:
                html_lines.append("<ul>")
                in_list = True
            content = stripped[2:]
            # Convert markdown links to HTML
            content = re.sub(
                r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', content
            )
            # Convert bold
            content = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", content)
            # Convert inline code
            content = re.sub(r"`([^`]+)`", r"<code>\1</code>", content)
            html_lines.append(f"  <li>{content}</li>")
        # Regular paragraph text
        else:
            if in_list:
                html_lines.append("</ul>")
                in_list = False
            # Convert inline formatting
            text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', stripped)
            text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
            text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
            html_lines.append(f"<p>{text}</p>")

    if in_list:
        html_lines.append("</ul>")

    return "\n".join(html_lines)


# Build release notes HTML
if release_notes.strip():
    notes_html = markdown_to_simple_html(release_notes)
    description_html = f"""
<h2>BetterCapture v{version}</h2>
{notes_html}
"""
else:
    description_html = f"""
<h2>BetterCapture v{version}</h2>
<p>This release was published on {now.strftime("%Y-%m-%d")}.</p>
<p>
View the full release notes on
<a href="{repo_url}/releases/tag/v{version}">GitHub</a>.
</p>
"""

# Create new appcast item
item = ET.SubElement(channel, "item")

elem = ET.SubElement(item, "title")
elem.text = f"Version {version}"

elem = ET.SubElement(item, "pubDate")
elem.text = now.strftime(pubdate_format)

elem = ET.SubElement(item, f"{{{SPARKLE_NS}}}version")
# Sparkle compares sparkle:version against CFBundleVersion
elem.text = build_number

elem = ET.SubElement(item, f"{{{SPARKLE_NS}}}shortVersionString")
elem.text = version

elem = ET.SubElement(item, f"{{{SPARKLE_NS}}}minimumSystemVersion")
elem.text = "26.0"

if release_url:
    elem = ET.SubElement(item, f"{{{SPARKLE_NS}}}fullReleaseNotesLink")
    elem.text = release_url

elem = ET.SubElement(item, "description")
elem.text = description_html

elem = ET.SubElement(item, "enclosure")
elem.set("url", dmg_url)
elem.set("type", "application/octet-stream")
for key, value in attrs.items():
    elem.set(key, value)

# Note: register_namespace() (called earlier) ensures xmlns declarations are
# written to output when elements with those namespaces are present. We don't
# need to set them explicitly as attributes.

# Write output
et.write("appcast_new.xml", xml_declaration=True, encoding="utf-8")
print(f"Generated appcast_new.xml for version {version}")
