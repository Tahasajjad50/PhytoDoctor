import React, { useState, useEffect } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import { Sidebar, NavigationTab } from './components/Sidebar';
import { AdminLogin } from './pages/AdminLogin';
import { OverviewDashboard } from './pages/OverviewDashboard';
import { VisitList } from './pages/VisitList';
import { EmployeeManagement } from './pages/EmployeeManagement';
import { TargetManagement } from './pages/TargetManagement';
import { EmployeePerformance } from './pages/EmployeePerformance';
import { TeamPerformance } from './pages/TeamPerformance';
import { ReportsExport } from './pages/ReportsExport';
import { AuditHistory } from './pages/AuditHistory';
import { SettingsPage } from './pages/SettingsPage';
import { api } from './services/api';

const MainLayout: React.FC = () => {
  const { user, token, isLoading } = useAuth();
  const [currentTab, setCurrentTab] = useState<NavigationTab>('overview');
  const [pendingReviewCount, setPendingReviewCount] = useState<number>(0);

  useEffect(() => {
    if (token) {
      // Fetch overview to update sidebar badge
      api.getCompanyOverview()
        .then((data) => {
          setPendingReviewCount(data.pending_review_count || 0);
        })
        .catch(() => {});
    }
  }, [token, currentTab]);

  if (isLoading) {
    return (
      <div
        style={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: 'var(--warm-offwhite)',
          flexDirection: 'column',
          gap: 16,
        }}
      >
        <img
          src="/assets/phytodoctor_icon.png"
          alt="Phyto Doctor"
          style={{ width: 56, height: 56, objectFit: 'contain' }}
        />
        <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--botanical-dark)' }}>
          Loading Phyto Doctor Administration Portal...
        </div>
      </div>
    );
  }

  if (!token || !user) {
    return <AdminLogin />;
  }

  return (
    <div className="app-layout">
      <Sidebar
        currentTab={currentTab}
        onSelectTab={setCurrentTab}
        pendingReviewCount={pendingReviewCount}
      />

      <main className="main-wrapper">
        {currentTab === 'overview' && (
          <OverviewDashboard onNavigate={(tab) => setCurrentTab(tab)} />
        )}
        {currentTab === 'visits' && <VisitList />}
        {currentTab === 'employees' && <EmployeeManagement />}
        {currentTab === 'targets' && <TargetManagement />}
        {currentTab === 'performance' && <EmployeePerformance />}
        {currentTab === 'team-performance' && <TeamPerformance />}
        {currentTab === 'reports' && <ReportsExport />}
        {currentTab === 'audit' && <AuditHistory />}
        {currentTab === 'settings' && <SettingsPage />}
      </main>
    </div>
  );
};

export const App: React.FC = () => {
  return (
    <AuthProvider>
      <MainLayout />
    </AuthProvider>
  );
};

export default App;
