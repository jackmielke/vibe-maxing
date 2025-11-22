# Vibe Maxing - Monorepo

A modern monorepo setup for the Vibe Maxing project using pnpm workspaces.

## 📁 Project Structure

```
vibe-maxing/
├── packages/
│   ├── frontend/          # React + Vite frontend application
│   │   ├── src/
│   │   ├── public/
│   │   ├── package.json
│   │   └── vite.config.ts
│   └── supabase/          # Supabase backend configuration
│       ├── config.toml
│       ├── functions/
│       ├── migrations/
│       └── package.json
├── package.json           # Root workspace configuration
├── pnpm-workspace.yaml    # Workspace definition
└── README.md
```

## 🚀 Getting Started

### Prerequisites

- Node.js >= 18.0.0
- pnpm >= 8.0.0

### Installation

Install pnpm globally if you haven't already:

```bash
npm install -g pnpm
```

Install all dependencies:

```bash
pnpm install
```

## 📦 Available Scripts

### Root Level Commands

```bash
# Start development server
pnpm dev

# Build for production
pnpm build

# Build for development
pnpm build:dev

# Run linter
pnpm lint

# Preview production build
pnpm preview

# Clean all node_modules and build artifacts
pnpm clean
```

### Package-Specific Commands

Run commands in specific packages:

```bash
# Frontend
pnpm --filter frontend dev
pnpm --filter frontend build

# Supabase
pnpm --filter supabase start
pnpm --filter supabase stop
pnpm --filter supabase status
```

## 🏗️ Workspace Management

This monorepo uses pnpm workspaces for package management. All packages are defined in `pnpm-workspace.yaml`.

### Adding Dependencies

```bash
# Add to root workspace
pnpm add -w <package-name>

# Add to specific package
pnpm --filter frontend add <package-name>
pnpm --filter supabase add <package-name>

# Add dev dependency
pnpm --filter frontend add -D <package-name>
```

### Running Commands Across All Packages

```bash
# Run a script in all packages
pnpm -r <script-name>

# Run in parallel
pnpm -r --parallel <script-name>
```

## 📝 Package Details

### Frontend (`packages/frontend`)

- **Framework**: React 18 + TypeScript
- **Build Tool**: Vite
- **UI Components**: Radix UI + Tailwind CSS
- **State Management**: TanStack Query
- **Routing**: React Router DOM

### Supabase (`packages/supabase`)

- **Database**: PostgreSQL
- **Functions**: Edge Functions
- **Migrations**: SQL migrations

## 🔧 Development Workflow

1. **Start Development**:
   ```bash
   pnpm dev
   ```

2. **Make Changes**: Edit files in the respective packages

3. **Build**:
   ```bash
   pnpm build
   ```

4. **Deploy**: Follow deployment instructions for each package

## 📚 Additional Resources

- [pnpm Workspaces Documentation](https://pnpm.io/workspaces)
- [Vite Documentation](https://vitejs.dev/)
- [Supabase Documentation](https://supabase.com/docs)

## 🤝 Contributing

1. Create a new branch
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## 📄 License

This project is private and proprietary.
