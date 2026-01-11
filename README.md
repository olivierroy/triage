# Triage

An AI-powered email management application built with Phoenix LiveView that connects to your Gmail account, automatically categorizes and summarizes emails using Google's Gemini AI.

## Features

- **Gmail Integration**: Connect your Gmail account via OAuth to fetch and manage emails
- **AI-Powered Categorization**: Automatically categorize emails using Google's Gemini AI
- **Email Summarization**: Get concise summaries of your emails highlighting key action items
- **Custom Categories**: Create and manage your own email categories with descriptions
- **Email Rules**: Define rules to automatically process, skip, or archive emails based on:
  - Sender addresses
  - Subject keywords
  - Body keywords
- **Bulk Operations**: Select multiple emails for bulk deletion and other operations
- **Real-time Sync**: Background jobs automatically sync new emails from your Gmail inbox
- **Email Archiving**: Option to automatically archive processed emails in Gmail

## Architecture

### Tech Stack

- **Phoenix LiveView** (v1.8.3) - Real-time web UI
- **Ecto** (v3.13) - Database ORM with PostgreSQL
- **Oban** (v2.17) - Background job processing
- **LangChain** (v0.4.1) - AI integration with Google Gemini
- **Tailwind CSS** - Styling
- **Phoenix LiveDashboard** - Application monitoring (dev)

### Key Components

- `Triage.Gmail` - Main Gmail API integration context
- `Triage.Gmail.AI` - AI service for categorization and summarization
- `Triage.Categories` - User category management
- `Triage.EmailRules` - Email processing rules engine
- `Triage.Emails.Email` - Email schema and persistence
- `Triage.Gmail.ImportWorker` - Background job for email imports
- `Triage.Gmail.SyncWorker` - Scheduled job for periodic email sync

## Getting Started

### Prerequisites

- Elixir 1.15+
- PostgreSQL
- Google Cloud project with:
  - Google Cloud OAuth credentials (Client ID & Secret)
  - Gemini API Key (for AI features)

### Environment Variables

Create a `.env` file or set the following environment variables:

```bash
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=triage_dev

# Google OAuth (for Gmail API)
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret

# Google Gemini API (for AI categorization)
GOOGLE_API_KEY=your_gemini_api_key

# Secret key base for Phoenix
SECRET_KEY_BASE=your_secret_key_base

# Encryption key for storing OAuth tokens
ENCRYPTION_KEY=your_encryption_key

# New Relic (monitoring, optional)
NEW_RELIC_LICENSE_KEY=your_new_relic_license_key
```

### Setup

```bash
# Install dependencies
mix deps.get

# Setup database
mix ecto.create
mix ecto.migrate

# (Optional) Seed database
mix run priv/repo/seeds.exs

# Install and build assets
npm install --prefix assets
mix assets.build
```

### Running

```bash
# Start the Phoenix server
mix phx.server

# Or start with IEx for interactive debugging
iex -S mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) to access the application.

### Development Tools

```bash
# Run tests
mix test

# Run precommit checks (compile, format, test)
mix precommit

# Format code
mix format

# Check code style
mix credo

# Dialyzer (type checking)
mix dialyzer

# View development dashboard
# Visit http://localhost:4000/dev/dashboard

# View Oban job dashboard
# Visit http://localhost:4000/dev/oban
```

## Configuration

### Email Rules

Email rules are evaluated in the order they're created. The first matching rule determines the action:

- **Process**: Import the email and apply AI categorization
- **Skip**: Skip importing the email entirely

Each rule can match on:
- `match_senders`: List of sender email addresses/patterns
- `match_subject_keywords`: Keywords to match in subject
- `match_body_keywords`: Keywords to match in email body

### AI Categorization

The AI uses Google's Gemini models (`gemini-2.5-flash-lite`) in JSON mode to:
- Analyze email subject, sender, and snippet
- Match against your custom categories
- Generate a 3-4 sentence summary highlighting key actions

### Background Jobs

Oban handles two types of jobs:
- **Import Worker**: Processes batches of emails when you click "Import"
- **Sync Worker**: Runs every minute to sync new emails from Gmail

## Deployment

### Playwright MCP Server

The application integrates with Playwright MCP server for browser automation capabilities. When running with Docker Compose, it uses the official `@playwright/mcp` server.

To enable Playwright MCP integration:
1. Set `PLAYWRIGHT_MCP_URL` to point to your Playwright MCP server
2. Start the Docker Compose services (includes `playwright-mcp`)
3. The Elixir app will automatically connect to the MCP server

### Docker

```bash
# Build and run with Playwright MCP server
docker compose up --build

# The application will be available at http://localhost:4000
# Playwright MCP server will be available at http://localhost:8931
```

### Production

```bash
# Compile for production
MIX_ENV=prod mix compile

# Build assets
mix assets.deploy

# Generate a release
mix release

# Start the production server
_build/prod/rel/triage/bin/triage start
```

See [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html) for more details.

## Learn More

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
- [Oban](https://hexdocs.pm/oban/)
- [LangChain](https://hexdocs.pm/langchain/)
- [Google Gmail API](https://developers.google.com/gmail/api)
- [Google Gemini API](https://ai.google.dev/gemini-api/docs)
