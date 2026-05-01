# ClackyAI Rails7 starter

The template for ClackyAI

## Installation

Install dependencies:

* postgresql

    ```bash
    $ brew install postgresql
    ```

    Ensure you have already initialized a user with username: `postgres` and password: `postgres`( e.g. using `$ createuser -d postgres` command creating one )

* rails 7

    Using `rbenv`, update `ruby` up to 3.x, and install `rails 7.x`

    ```bash
    $ ruby -v ( output should be 3.x )

    $ gem install rails

    $ rails -v ( output should be rails 7.x )
    ```

* npm

    Make sure you have Node.js and npm installed

    ```bash
    $ npm --version ( output should be 8.x or higher )
    ```

Install dependencies, setup db:
```bash
$ ./bin/setup
```

Start it:
```
$ bin/dev
```

## Admin dashboard info

This template already have admin backend for website manager, do not write business logic here.

Access url: /admin

Default superuser: admin

Default password: admin

## Tech stack

* Ruby on Rails 7.x
* Tailwind CSS 3 (with custom design system)
* Hotwire Turbo (Drive, Frames, Streams)
* Stimulus
* ActionCable
* figaro
* postgres
* active_storage
* kaminari
* puma
* rspec

## Documentation

### AI Tool System

* **[Tool Capabilities](TOOL_CAPABILITIES.md)** - Complete list of all AI tools (Level 1-10)
* **[Tool Maintenance Guide](docs/TOOL_MAINTENANCE_GUIDE.md)** - How to add, update, or remove AI tools
* **[Example: Adding a New Tool](docs/EXAMPLE_NEW_TOOL.md)** - Step-by-step example of adding a `find_todos` tool
* **[Project Documentation](docs/project.md)** - Deployment, architecture, and environment setup

### Quick Links

**Want to add a new tool to your AI assistant?**
1. Read [Tool Maintenance Guide](docs/TOOL_MAINTENANCE_GUIDE.md) for complete instructions
2. See [Example: Adding a New Tool](docs/EXAMPLE_NEW_TOOL.md) for a real-world implementation
3. Check [Tool Capabilities](TOOL_CAPABILITIES.md) to understand existing tools