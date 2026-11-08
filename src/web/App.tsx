import { Navigate, Route, Routes } from 'react-router';
import { ErrorState } from './components/ui';
import { LoginPage } from './features/auth/LoginPage';
import { WorkspaceRoute } from './features/auth/session';
import { MyBookingsPage } from './features/bookings/MyBookingsPage';
import { CalendarPage } from './features/calendar/CalendarPage';
import { LandingPage } from './features/landing/LandingPage';
import { OutboxPage } from './features/outbox/OutboxPage';
import { PreferencesPage } from './features/preferences/PreferencesPage';
import { SettingsPage } from './features/settings/SettingsPage';
import { AppShell } from './features/shell/AppShell';

function NotFoundPage() {
  return (
    <main className="page page--narrow">
      <ErrorState title="Page not found" message="There is nothing at this address." />
    </main>
  );
}

export function App() {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/preferences/:token" element={<PreferencesPage />} />
      <Route
        path="/w/:workspaceId"
        element={<WorkspaceRoute shell={(content) => <AppShell>{content}</AppShell>} />}
      >
        <Route index element={<Navigate to="calendar" replace />} />
        <Route path="calendar" element={<CalendarPage />} />
        <Route path="bookings" element={<MyBookingsPage />} />
        <Route path="outbox" element={<OutboxPage />} />
        <Route path="settings" element={<SettingsPage />} />
      </Route>
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}
