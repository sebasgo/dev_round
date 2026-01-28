# DevRound

DevRound is a comprehensive event management platform for organizing
coding events and programming workshops. It provides real-time
collaboration features, intelligent team formation, and live
presentation capabilities.

## Features

- **Multi-session Events**: Create events with multiple coding sessions
- **Programming Languages**: Support for multiple languages (Python,
  Elixir, C++, Fortran, Julia, etc.)
- **Registration System**: Self-service registration with deadline
  enforcement
- **Hybrid Support**: Separate handling for remote and in-person
  attendees
- **Live Presentations**: PDF slide viewer with remote control
  capabilities
- **LDAP Authentication**: Support for enterprise authentication via
  LDAP

### Intelligent Team Formation

- **Automated Pairing**: Algorithm-driven team generation based on:
  - Experience level balancing (stratified pairing)
  - Shared programming language preferences
  - Remote vs. in-person status
- **Check-in Management**: Attendee verification before team formation
  - Check in attendees on arrival
  - Check out attendees if they need to leave early

### Real-time Collaboration

- **Live Updates**: Real-time updates across all views
- **Remote Slide Control**: Hosts control presentation slides for all
  attendees
- **Session Management**: Start, stop, and reset event sessions
  dynamically
- **Registration Notifications**: Instant updates when users register or
  modify attendance

### Admin Interface

- **Admin Panel**: CRUD operations for all resources
- **Event Duplication**: Clone events to save time
- **User Management**: Manage hosts and attendees

## Getting Started

### Prerequisites

- Elixir 1.14 or later
- Node.js (for asset compilation)
- PostgreSQL database (or Podman to run it in a container)
- OpenLDAP server (or Podman to run it in a container)

### Installation

1. **Clone the repository**

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

3. **Start OpenLDAP server**

   **Option A: Using Podman (recommended for development)**
   ```bash
   ./contrib/run-openldap-podman
   ```
   This script will:
   - Create an OpenLDAP container with proper user mappings
   - Expose LDAP on ports 5389 (LDAP) and 5636 (LDAPS)
   - Configure default organization ("Development Corp") and domain (dev.local)
   - Set up initial users and groups for testing

   **Option B: Use your local OpenLDAP installation**
   - Ensure OpenLDAP is running
   - Configure appropriate LDAP settings in your environment

4. **Install dependencies and setup database**:

```bash
mix setup
```

This will:
- Install Elixir dependencies
- Create and migrate the database
- Run database seeds
- Install and build frontend assets

5. **Start the Phoenix server**:

```bash
mix phx.server
```

Or start it inside IEx:
```bash
iex -S mix phx.server
```

6. **Visit [`http://localhost:4000`](http://localhost:4000) in your
browser**

## Usage

### Sample users

The containerized LDAP instance is pre-populated with the following user
accounts which can be used to log in. For all accounts, the user name
and the password are identical.

| Full Name          | UID / Password | Role  |
|--------------------|----------------|-------|
| John Doe           | jdoe           | Admin |
| Alice Smith        | asmith         | User  |
| Bob Wilson         | bwilson        | User  |
| Carol Johnson      | cjohnson       | User  |
| David Lee          | dlee           | User  |
| Elena Martinez     | emartinez      | User  |
| Frank Garcia       | fgarcia        | User  |
| Grace Davis        | gdavis         | User  |
| Henry Brown        | hbrown         | User  |
| Isabel Thompson    | ithompson      | User  |
| James White        | jwhite         | User  |
| Kate Harris        | kharris        | User  |
| Lucas Martin       | lmartin        | User  |
| Maria Clark        | mclark         | User  |
| Nathan Lewis       | nlewis         | User  |
| Olivia Walker      | owalker        | User  |
| Peter Hall         | phall          | User  |
| Quinn Allen        | qallen         | User  |
| Rachel Young       | ryoung         | User  |
| Samuel King        | sking          | User  |
| Taylor Wright      | twright        | User  |
| Uma Lopez          | ulopez         | User  |
| Victor Hill        | vhill          | User  |
| Wendy Scott        | wscott         | User  |
| Xavier Green       | xgreen         | User  |
| Yara Adams         | yadams         | User  |
| Zachary Baker      | zbaker         | User  |
| Amanda Nelson      | anelson        | User  |
| Brandon Carter     | bcarter        | User  |
| Christina Mitchell | cmitchell      | User  |
| Daniel Perez       | dperez         | User  |
| Emma Roberts       | eroberts       | User  |

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
- **Frontend**: Tailwind CSS v4, daisyUI v5, Heroicons

For detailed technical documentation, architecture details, and development guidelines, see [AGENTS.md](AGENTS.md).

## Learn More

- **Phoenix Framework**: https://www.phoenixframework.org/
- **Phoenix LiveView**: https://hexdocs.pm/phoenix_live_view/
- **Backpex**: https://backpex.live/

## License

All rights reserved.
