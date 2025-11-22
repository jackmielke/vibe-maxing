# Frontend Package

React + TypeScript + Vite frontend application for Vibe Maxing.

## 🚀 Tech Stack

- **Framework**: React 18
- **Language**: TypeScript
- **Build Tool**: Vite
- **Styling**: Tailwind CSS
- **UI Components**: Radix UI
- **State Management**: TanStack Query
- **Routing**: React Router DOM
- **Form Handling**: React Hook Form + Zod
- **Backend**: Supabase

## 📁 Project Structure

```
src/
├── components/          # Reusable components
│   ├── ui/             # UI components (shadcn/ui)
│   ├── CosmicBackground.tsx
│   ├── NavLink.tsx
│   └── VibeCatcherGame.tsx
├── pages/              # Page components
│   ├── Index.tsx
│   └── NotFound.tsx
├── hooks/              # Custom React hooks
│   ├── use-mobile.tsx
│   └── use-toast.ts
├── integrations/       # External integrations
│   └── supabase/
├── lib/                # Utility functions
│   └── utils.ts
├── App.tsx             # Main app component
├── main.tsx            # Entry point
└── index.css           # Global styles
```

## 🛠️ Development

### Start Development Server

```bash
# From root
pnpm dev

# From this package
pnpm dev
```

The app will be available at `http://localhost:8080`

### Build for Production

```bash
pnpm build
```

### Preview Production Build

```bash
pnpm preview
```

### Lint Code

```bash
pnpm lint
```

## 🎨 UI Components

This project uses [shadcn/ui](https://ui.shadcn.com/) components built on top of Radix UI and Tailwind CSS.

### Available Components

- Accordion
- Alert Dialog
- Avatar
- Button
- Card
- Checkbox
- Dialog
- Dropdown Menu
- Form
- Input
- Select
- Tabs
- Toast
- Tooltip
- And many more...

### Adding New Components

```bash
# From root
pnpm --filter frontend add <component-name>
```

## 🔧 Configuration

### Vite Config (`vite.config.ts`)

- Server port: 8080
- Path alias: `@` → `./src`
- React SWC plugin for fast refresh
- Component tagger for development

### TypeScript Config

- Base URL: `.`
- Path mapping: `@/*` → `./src/*`
- Strict type checking disabled for flexibility

### Tailwind Config (`tailwind.config.ts`)

- Custom theme configuration
- Dark mode support
- Custom animations
- Typography plugin

## 🌐 Environment Variables

Create a `.env` file in the root directory:

```env
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

## 📦 Key Dependencies

### Core
- `react` - UI library
- `react-dom` - React DOM rendering
- `react-router-dom` - Routing

### UI & Styling
- `@radix-ui/*` - Headless UI components
- `tailwindcss` - Utility-first CSS
- `lucide-react` - Icon library
- `class-variance-authority` - Component variants
- `tailwind-merge` - Merge Tailwind classes

### State & Data
- `@tanstack/react-query` - Data fetching & caching
- `@supabase/supabase-js` - Supabase client
- `react-hook-form` - Form handling
- `zod` - Schema validation

### Utilities
- `date-fns` - Date utilities
- `clsx` - Conditional classes
- `sonner` - Toast notifications

## 🎯 Features

- **Modern UI**: Beautiful, responsive design with Tailwind CSS
- **Type Safety**: Full TypeScript support
- **Fast Refresh**: Instant feedback with Vite HMR
- **Component Library**: Rich set of accessible UI components
- **Form Validation**: Robust form handling with validation
- **Data Fetching**: Efficient data management with TanStack Query
- **Routing**: Client-side routing with React Router
- **Dark Mode**: Built-in theme support

## 📝 Code Style

### Component Structure

```typescript
import { useState } from 'react';
import { Button } from '@/components/ui/button';

interface MyComponentProps {
  title: string;
  onAction?: () => void;
}

export const MyComponent = ({ title, onAction }: MyComponentProps) => {
  const [isActive, setIsActive] = useState(false);

  return (
    <div className="flex flex-col gap-4">
      <h2 className="text-2xl font-bold">{title}</h2>
      <Button onClick={onAction}>
        Click me
      </Button>
    </div>
  );
};
```

### Import Order

1. React & external libraries
2. Internal components
3. Utilities & helpers
4. Types & interfaces
5. Styles

## 🔗 Related Packages

- `supabase` - Backend configuration and functions

## 📚 Resources

- [React Documentation](https://react.dev/)
- [Vite Documentation](https://vitejs.dev/)
- [Tailwind CSS](https://tailwindcss.com/)
- [shadcn/ui](https://ui.shadcn.com/)
- [Radix UI](https://www.radix-ui.com/)
- [TanStack Query](https://tanstack.com/query/)

## 🐛 Troubleshooting

### Port Already in Use

Change the port in `vite.config.ts`:

```typescript
server: {
  port: 3000, // Your preferred port
}
```

### Module Not Found

Clear cache and reinstall:

```bash
rm -rf node_modules
pnpm install
```

### Build Errors

Check TypeScript errors:

```bash
pnpm tsc --noEmit
```

---

For more information, see the [root README](../../README.md).

