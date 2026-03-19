# YouTube Channel Cloning & Automated Video Generation with Google NotebookLM

> **Source:** AI Prreneur YouTube Channel  
> **Topic:** Reverse-engineering monetized YouTube channels and automating video production using free Google AI tools  
> **Primary Tool:** [Google NotebookLM](https://notebooklm.google.com)

---

## Overview

This document captures a complete workflow for analyzing successful faceless YouTube channels, extracting their content formula, and producing full videos (script, voiceover, visuals) automatically using Google NotebookLM — a free AI-powered research and content generation tool.

The approach targets faceless/AI-narrated channels in evergreen niches (psychology, personal finance, relationships, productivity, health) that monetize without personal branding, on-camera presence, or advanced editing.

---

## Case Study Referenced

- **Channel type:** Faceless, AI-voiced, basic animation
- **Age:** ~4 months old
- **Videos uploaded:** ~54
- **Estimated monthly revenue:** ~$3,000/month
- **Analytics tool used:** [vidIQ](https://vidiq.com) — YouTube analytics and growth platform for tracking channel performance, keyword research, and competitor analysis

**Key takeaway:** Success came from the content formula (topic selection, hooks, structure, pacing), not production quality.

---

## Tools Required

| Tool | Purpose | Cost | Link |
|------|---------|------|------|
| **Google NotebookLM** | Content analysis, script generation, video generation | Free (basic) / $249.99/mo for Cinematic (Ultra) | [notebooklm.google.com](https://notebooklm.google.com) |
| **Grabbit** (Chrome Extension) | Bulk-copy video URLs from YouTube channel pages | Free | [Chrome Web Store](https://chromewebstore.google.com/detail/grabbit/madmdgpjgagdmmmiddpiggdnpgjglcdk) |
| **vidIQ** (Chrome Extension) | YouTube channel analytics and revenue estimation | Freemium | [vidiq.com](https://vidiq.com) |
| **Canva** | Thumbnail creation | Free tier available | [canva.com](https://www.canva.com) |

---

## Step-by-Step Workflow

### Phase 1: Channel Research & Link Collection

1. **Find a target channel** on YouTube in your chosen niche
   - Look for: consistent uploads, good view counts, verified monetization
   - Ideal: faceless channels with AI narration and simple visuals

2. **Install & configure Grabbit Chrome extension**
   - Install from Chrome Web Store
   - Pin it to your toolbar (puzzle piece icon → pin)
   - Open Grabbit settings → "Add New Action"
     - Mouse button: **Left Click**
     - Modifier button: **Alt**
     - Box color: leave default
     - Action type: **Copy URLs to Clipboard**
     - Save

3. **Bulk-copy video links**
   - Go to the target channel's Videos tab
   - Hold **Alt + Left Click**, then scroll down slowly
   - A selection box highlights all video links as you scroll
   - Cover at least 10–15 videos (more = better results)
   - Release click — all URLs are now on your clipboard

### Phase 2: NotebookLM Setup & Channel Analysis

4. **Create a new NotebookLM notebook**
   - Go to [notebooklm.google.com](https://notebooklm.google.com) and sign in with Google
   - Click "New Notebook"
   - Title it descriptively (e.g., "Channel Clone — [Niche Name]")

5. **Add video sources**
   - Click "Add Sources" → select "Website"
   - Paste all copied video URLs at once
   - Click "Insert" — NotebookLM processes each video
   - **Pro tip:** While loading, add more sources (blog posts, articles, PDFs related to your niche) for richer context

6. **Extract the channel formula** — Type this in the chat:
   > "Analyze all of these videos and extract the formula behind this channel. Include: target audience, top-performing topic types, tone and energy, hook patterns, and script structure."

   NotebookLM returns a full breakdown — this is the channel's decoded playbook. Save it.

7. **Generate channel name ideas** — Follow up with:
   > "Based on this formula, generate 10 YouTube channel name ideas with a short explanation for each."

8. **Generate video ideas** — Then ask:
   > "Generate 10 video ideas based on this channel's proven formula. Include a title, hook, and brief description for each."

### Phase 3: Script Generation (Batch Process)

9. **Pick a video idea** from the 10 generated and copy its full details (title, hook, description)

10. **Create a dedicated notebook** for each video
    - Dashboard → "New Notebook" → title it with the video name
    - Add Source → "Copy Text" → paste the video idea details → Insert

11. **Generate the full script** back in the main notebook chat:
    > "Write a complete YouTube script for this video idea: [paste idea]. Use the same tone, structure, and pacing as the analyzed channel."

12. **Copy the script** into the video-specific notebook as an additional source

13. **Repeat for multiple videos** — work in parallel across notebooks to batch content

### Phase 4: Video Generation

14. **Open the Studio tab** in the video-specific notebook

15. **Click "Video Overview"** and configure:
    - **Format:** Explainer (best for educational/how-to content)
    - **Language:** Select your target language (80+ supported)
    - **Visual Style:** Whiteboard recommended for educational channels (other options: Classic, Watercolor, Retro Print, Heritage, Paper-craft, Kawaii, Anime, or Custom)

16. **Hit Generate** — NotebookLM automatically:
    - Reads your script
    - Builds matching visuals
    - Records AI voiceover
    - Assembles the full video

17. **Preview** the completed video in-browser

### Phase 5: Optimization (Title, Description, Thumbnail)

18. **Generate title options** in the video notebook chat:
    > "Generate 10 compelling YouTube title options for this video with a brief explanation for each."

19. **Generate video description:**
    > "Write an SEO-optimized YouTube description for this video."

20. **Create thumbnail in Canva:**
    - Go to [canva.com](https://www.canva.com) → search "YouTube Thumbnail"
    - In Elements, search "[your topic] stick figure"
    - Position illustration on one side, add shadow/glow
    - Add a bold 4–6 word text overlay
    - Place a red rectangle behind the text
    - Set text to white, font to Poppins
    - Balance and export

---

## NotebookLM Key Details (as of March 2026)

### Supported Source Types
- YouTube video URLs
- Websites/URLs
- Google Docs, Slides, Sheets
- PDFs, .docx files
- Audio files (MP3, WAV, 20+ formats)
- Text files, images (with OCR), CSV files
- Up to 500,000 words or 200MB per source

### Video Overview Tiers
| Feature | Free Plan | Plus ($19.99/mo) | Ultra ($249.99/mo) |
|---------|-----------|-------------------|---------------------|
| Notebooks | 100 | More | Unlimited |
| Sources per notebook | 50 | 50 | 50 |
| Chat queries/day | 50 | More | Unlimited |
| Audio/Video generations/day | 3 | More | 20 cinematic/day |
| Video style | Explainer, Brief | Explainer, Brief + Visual Styles | All + Cinematic |
| Cinematic (Veo 3) | No | No | Yes |

### Cinematic Video Overviews (Ultra only)
- Powered by Gemini 3 + Nano Banana Pro + Veo 3
- Generates actual animated sequences (not slideshows)
- English only at launch
- No post-generation editing — regenerate with refined prompts if needed

---

## Relevance to IronClaw

This workflow can be partially automated through an IronClaw agent:

- **MCP Integration:** Use browser automation MCP servers to automate the Grabbit link collection step
- **Skills:** Create a `SKILL.md` that encodes the prompt sequence (formula extraction → name generation → video ideas → script writing)
- **Routines:** Set up cron-triggered routines to periodically analyze trending channels in a niche and generate content pipelines
- **Channels:** Deliver generated scripts and video links via Telegram, Discord, or Slack

Example IronClaw commands:
```bash
# Add a YouTube content skill
ironclaw skill install youtube-content-pipeline

# Or create a local skill
cat > /data/.ironclaw/skills/youtube-clone.SKILL.md << 'EOF'
# YouTube Channel Clone Assistant
Activation: youtube clone, channel analysis, video script
---
You help users reverse-engineer successful YouTube channels and generate content using Google NotebookLM.
...
EOF
```

---

## Sources

- [Google NotebookLM — Video Overview Documentation](https://support.google.com/notebooklm/answer/16454555?hl=en)
- [Google Blog — Cinematic Video Overviews Announcement (March 4, 2026)](https://blog.google/innovation-and-ai/products/notebooklm/generate-your-own-cinematic-video-overviews-in-notebooklm/)
- [Build Fast with AI — NotebookLM Cinematic Guide (2026)](https://www.buildfastwithai.com/blogs/notebooklm-cinematic-video-overview-full-guide-2026)
- [Grabbit Chrome Extension — GitHub](https://github.com/socratespap/Grabbit-1.0.3-release)
- [Grabbit — Chrome Web Store](https://chromewebstore.google.com/detail/grabbit/madmdgpjgagdmmmiddpiggdnpgjglcdk)
- [vidIQ — YouTube Analytics Platform](https://vidiq.com)
