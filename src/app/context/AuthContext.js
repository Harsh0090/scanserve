
//AuthContext.js
"use client";
import { createContext, useContext, useEffect, useState } from "react";
import { apiFetch } from '../../utils/apiClient';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading2, setloading2] = useState(true);

  const loadSession = async () => {
    try {
      const res = await apiFetch("/api/auth/me");
      const userData = res.data || res;
      
      // Robust check: if we have restaurantId or role, it's a valid session data
      if (res.success || (userData && (userData.restaurantId || userData.role))) {
        setUser(userData);
      } else {
        setUser(null);
      }
    } catch (err) {
      setUser(null);
    } finally {
      setloading2(false);
    }
  };

  useEffect(() => {
    loadSession();
  }, []);

  return (
    <AuthContext.Provider value={{ user, loading2, reload: loadSession }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);