import React from 'react';
import {
  LayoutDashboard,
  Users,
  Target,
  ClipboardList,
  BarChart3,
  Users2,
  FileSpreadsheet,
  History,
  Settings,
  LogOut,
  ShieldCheck,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export type NavigationTab =
  | 'overview'
  | 'employees'
  | 'targets'
  | 'visits'
  | 'performance'
  | 'team-performance'
  | 'reports'
  | 'audit'
  | 'settings';

interface SidebarProps {
  currentTab: NavigationTab;
  onSelectTab: (tab: NavigationTab) => void;
  pendingReviewCount?: number;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  onSelectTab,
  pendingReviewCount = 0,
}) => {
  const { user, logout, isOwner, isManager } = useAuth();

  const navItems = [
    { id: 'overview' as NavigationTab, label: 'Overview Dashboard', icon: LayoutDashboard },
    { id: 'visits' as NavigationTab, label: 'Field Visits', icon: ClipboardList, badge: pendingReviewCount > 0 ? pendingReviewCount : undefined },
    { id: 'employees' as NavigationTab, label: 'Employee Roster', icon: Users },
    { id: 'targets' as NavigationTab, label: 'Target Management', icon: Target },
    { id: 'performance' as NavigationTab, label: 'Employee Analytics', icon: BarChart3 },
    { id: 'team-performance' as NavigationTab, label: 'Team Leaderboard', icon: Users2 },
    { id: 'reports' as NavigationTab, label: 'Reports & Export', icon: FileSpreadsheet },
    { id: 'audit' as NavigationTab, label: 'Audit History', icon: History },
    { id: 'settings' as NavigationTab, label: 'System Settings', icon: Settings },
  ];

  return (
    <aside className="sidebar">
      {/* Brand Header */}
      <div className="sidebar-header">
        <img
          src="/assets/phytodoctor_icon.png"
          alt="Phyto Doctor"
          className="sidebar-logo"
          onError={(e) => {
            // Fallback if image fails to render
            (e.target as HTMLImageElement).style.display = 'none';
          }}
        />
        <div>
          <div className="sidebar-brand-title">Phyto Doctor</div>
          <div className="sidebar-brand-tag">Admin Operations</div>
        </div>
      </div>

      {/* Navigation List */}
      <nav className="sidebar-nav">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = currentTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => onSelectTab(item.id)}
              className={`sidebar-nav-item ${isActive ? 'active' : ''}`}
              type="button"
            >
              <Icon size={18} />
              <span>{item.label}</span>
              {item.badge !== undefined && (
                <span className="nav-badge">{item.badge}</span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Profile & Logout Footer */}
      <div className="sidebar-footer">
        <div className="user-profile-badge">
          <div className="user-profile-info">
            <div className="user-name">{user?.full_name || user?.username}</div>
            <span className={`user-role-tag ${isOwner ? 'owner' : 'manager'}`}>
              <ShieldCheck size={10} style={{ display: 'inline', marginRight: 3 }} />
              {user?.role}
            </span>
          </div>
          <button
            onClick={() => logout()}
            className="btn btn-secondary btn-icon-only"
            title="Log Out"
            type="button"
            style={{ color: '#FFFFFF', backgroundColor: 'rgba(255, 255, 255, 0.1)', borderColor: 'transparent' }}
          >
            <LogOut size={16} />
          </button>
        </div>
      </div>
    </aside>
  );
};
