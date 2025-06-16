# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose
This is a Zenn documentation repository for publishing technical articles primarily focused on SORACOM IoT platform technologies. Content is published to zenn.dev for the Japanese developer community.

## Repository Structure
- `/articles/` - Technical articles in Markdown format with YAML frontmatter
- `/books/` - Book-length publications (currently empty)
- `/scraps/` - JSON files for shorter informal posts/notes
- `/images/` - Image assets organized by article/topic folders
- `/files/` - Utility scripts and downloadable assets

## Article Format
Each article follows this structure:
```yaml
---
title: "Article Title"
emoji: "📅"
type: "tech" # or "idea"
topics: [tag1, tag2]
published: true
---
```

## Common Commands

### Image Path Management
```bash
# Fix relative image paths to absolute paths for Zenn compatibility
./imagepathpatch.sh
```

### SORACOM CLI Utilities
```bash
# Check SIM data usage for a date range
./files/check_sim_data_usage.sh [FROM_DATE] [TO_DATE]
# Example: ./files/check_sim_data_usage.sh 2024-07-01 2024-10-31
```

## Content Management Workflow
1. Create new articles in `/articles/` directory
2. Place images in organized folders under `/images/`
3. Use relative paths `../images/folder/image.png` when writing
4. Run `./imagepathpatch.sh` to convert to absolute paths `/images/folder/image.png`
5. Publish through Zenn platform

## Content Focus
Articles primarily cover:
- SORACOM Air (cellular connectivity)
- SORACOM Flux (data processing platform)
- SoraCam (IoT cameras)
- AWS integrations
- IoT tutorials and cheat sheets

## Development Notes
- No build process - content-only repository
- No package.json or Node.js dependencies
- Manual content management through Zenn CLI
- Images should be organized in topic-specific folders
- SORACOM CLI is used for data collection and monitoring utilities