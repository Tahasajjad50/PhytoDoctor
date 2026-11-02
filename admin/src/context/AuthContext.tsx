import React, { createContext, useContext, useEffect, useState } from 'react';
import { api } from '../services/api';
import { User } from '../types';

interface AuthContextType {
  user: User | null;
  token: string | null;
  isLoading: boolean;
  login: (usernameOrEmail: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  isOwner: boolean;
  isManager: boolean;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(() => {
    const saved = localStorage.getItem('phyto_admin_user');
    return saved ? JSON.parse(saved) : null;
  });
  const [token, setToken] = useState<string | null>(() => {
    return localStorage.getItem('phyto_admin_token');
  });
  const [isLoading, setIsLoading] = useState<boolean>(true);

  const refreshUser = async () => {
    if (!token) {
      setUser(null);
      setIsLoading(false);
      return;
    }
    try {
      const me = await api.getCurrentUser();
      // Ensure role is OWNER or MANAGER
      if (me.role !== 'OWNER' && me.role !== 'MANAGER') {
        throw new Error('Unauthorized role: Employee accounts cannot access the Administrator dashboard.');
      }
      setUser(me);
      localStorage.setItem('phyto_admin_user', JSON.stringify(me));
    } catch (err) {
      console.error('Failed to restore session:', err);
      localStorage.removeItem('phyto_admin_token');
      localStorage.removeItem('phyto_admin_user');
      setUser(null);
      setToken(null);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    refreshUser();
  }, [token]);

  const login = async (usernameOrEmail: string, password: string) => {
    setIsLoading(true);
    try {
      const res = await api.login(usernameOrEmail, password);
      if (res.user.role !== 'OWNER' && res.user.role !== 'MANAGER') {
        throw new Error('Access denied: Only Owners and Managers can access the administration dashboard.');
      }
      localStorage.setItem('phyto_admin_token', res.access_token);
      localStorage.setItem('phyto_admin_user', JSON.stringify(res.user));
      setToken(res.access_token);
      setUser(res.user);
    } finally {
      setIsLoading(false);
    }
  };

  const logout = async () => {
    setIsLoading(true);
    try {
      await api.logout();
    } finally {
      setUser(null);
      setToken(null);
      setIsLoading(false);
    }
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        isLoading,
        login,
        logout,
        isOwner: user?.role === 'OWNER',
        isManager: user?.role === 'MANAGER',
        refreshUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
