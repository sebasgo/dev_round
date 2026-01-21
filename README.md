# DevRound

DevRound is a comprehensive event management platform for organizing coding events and programming workshops. Built with Phoenix LiveView, it provides real-time collaboration features, intelligent team formation, and live presentation capabilities.

## Features

- **Multi-session Events**: Create events with multiple sessions
- **Programming Languages**: Support for multiple languages (Python, Elixir, C++, Fortran, Julia, etc.)
- **Registration System**: Time-limited registration with deadline enforcement
- **Hybrid Support**: Separate handling for remote and in-person attendees
- **Live Presentations**: PDF slide viewer with remote control capabilities

### Intelligent Team Formation
- **Automated Pairing**: Algorithm-driven team generation based on:
  - Experience level balancing (stratified pairing)
  - Shared programming language preferences
  - Remote vs. in-person status
- **Team Names Pool**: Pre-configured team names for quick assignment
- **Check-in Management**: Attendee verification before team formation
  - Check in attendees on arrival
  - Check out attendees if they need to leave early

### Real-time Collaboration
- **Live Updates**: PubSub-powered real-time updates across all views
- **Remote Slide Control**: Hosts control presentation slides for all attendees
- **Session Management**: Start, stop, and reset event sessions dynamically
- **Registration Notifications**: Instant updates when users register or modify attendance

### Admin Interface
- **Backpex-powered Admin Panel**: Full CRUD operations for all resources
- **Event Duplication**: Clone events to save time
- **User Management**: Manage hosts and attendees

## Getting Started

### Prerequisites

- Elixir 1.14 or later
- PostgreSQL database (or Podman/Docker to run it in a container)
- Node.js (for asset compilation)

### Installation

1. Clone the repository:

```bash
git clone git@github.com:sebasgo/dev_round.git
cd dev_round
```

2. **Start PostgreSQL database** 

   **Option A: Using Podman (recommended for development)**
   ```bash
   ./contrib/run-posgres-podman
   ```
   This script will:
   - Create a PostgreSQL 17 container with proper user mappings
   - Expose PostgreSQL on port 5432
   - Store data persistently in `~/.local/share/postgres` on the host system
   - Configure default credentials (user: `postgres`, password: `postgres`)
   
   **Option B: Use your local PostgreSQL installation**
   - Ensure PostgreSQL is running
   - Update `config/dev.exs` with your database credentials if needed

3. Install dependencies and setup database:

```bash
mix setup
```

This will:
- Install Elixir dependencies
- Create and migrate the database
- Run database seeds
- Install and build frontend assets

4. Start the Phoenix server:
```bash
mix phx.server
```

Or start it inside IEx:
```bash
iex -S mix phx.server
```

5. Visit [`http://localhost:4000`](http://localhost:4000) in your browser

## Usage

### For Event Organizers

1. **Create an Event**:
   - Log in to the admin panel at `/admin`
   - Create a new event with title, dates, location, and description
   - Add one or more sessions within the event timeframe
   - Select programming languages and assign hosts
   - Upload presentation slides (optional)
   - Set registration deadline and publish

2. **Host an Event**:
   - Navigate to the event hosting lobby
   - Check in attendees as they arrive
   - Review any constraint validation messages
   - Generate balanced teams (algorithm pairs by experience and languages)
   - Start the live presentation from the lecture view
   - Start sessions to reveal teams to attendees
   - Switch between lecture and session views as needed

### For Attendees

1. **Register for an Event**:
   - Browse events at `/events`
   - View event details
   - Register before the deadline with:
     - Programming language preferences
     - Remote or in-person attendance preference
   - Edit your registration anytime before the deadline

2. **Follow an Event**:
   - View live presentations at `/events/:slug/live`
   - See your team assignment when sessions start

## Development

### Running Tests
```bash
mix test
```

### Before Committing
```bash
mix precommit
```

This runs compilation, formatting, and tests to ensure code quality.

## Technology

- **Framework**: Phoenix 1.8 with LiveView 1.1
- **Database**: PostgreSQL with Ecto
- **Admin**: Backpex 0.16
- **Frontend**: Tailwind CSS v4, Heroicons
- **Real-time**: Phoenix PubSub

For detailed technical documentation, architecture details, and development guidelines, see [AGENTS.md](AGENTS.md).

## Learn More

- **Phoenix Framework**: https://www.phoenixframework.org/
- **Phoenix LiveView**: https://hexdocs.pm/phoenix_live_view/
- **Backpex**: https://backpex.live/

## License

All rights reserved.
