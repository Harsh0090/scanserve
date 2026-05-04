/**
 * QR Serve - Security Utilities
 * Secure localStorage implementation with encryption and session management
 */

// Simple encryption/decryption using base64 and XOR cipher
// For production, consider using Web Crypto API or a robust encryption library
const ENCRYPTION_KEY = "QRServe2024SecureKey"; // In production, use environment variable

/**
 * XOR Cipher for basic obfuscation
 */
function xorCipher(text, key) {
  let result = "";
  for (let i = 0; i < text.length; i++) {
    result += String.fromCharCode(text.charCodeAt(i) ^ key.charCodeAt(i % key.length));
  }
  return result;
}

/**
 * Secure Storage Manager
 */
export const secureStorage = {
  /**
   * Securely store data in localStorage with encryption and expiry
   */
  setItem: (key, value, expiryHours = 24) => {
    try {
      const data = {
        value: value,
        timestamp: Date.now(),
        expiry: Date.now() + (expiryHours * 60 * 60 * 1000)
      };
      
      // Convert to JSON and encrypt
      const jsonString = JSON.stringify(data);
      const encrypted = xorCipher(jsonString, ENCRYPTION_KEY);
      const encoded = btoa(encrypted);
      
      localStorage.setItem(`qrs_${key}`, encoded);
      return true;
    } catch (err) {
      console.error("Secure storage set error:", err);
      return false;
    }
  },

  /**
   * Retrieve and decrypt data from localStorage
   */
  getItem: (key) => {
    try {
      const encoded = localStorage.getItem(`qrs_${key}`);
      if (!encoded) return null;
      
      // Decrypt and parse
      const encrypted = atob(encoded);
      const decrypted = xorCipher(encrypted, ENCRYPTION_KEY);
      const data = JSON.parse(decrypted);
      
      // Check expiry
      if (Date.now() > data.expiry) {
        secureStorage.removeItem(key);
        return null;
      }
      
      return data.value;
    } catch (err) {
      console.error("Secure storage get error:", err);
      // If data is corrupted, remove it
      secureStorage.removeItem(key);
      return null;
    }
  },

  /**
   * Remove item from localStorage
   */
  removeItem: (key) => {
    try {
      localStorage.removeItem(`qrs_${key}`);
      return true;
    } catch (err) {
      console.error("Secure storage remove error:", err);
      return false;
    }
  },

  /**
   * Clear all QR Serve data from localStorage
   */
  clear: () => {
    try {
      const keys = Object.keys(localStorage);
      keys.forEach(key => {
        if (key.startsWith('qrs_')) {
          localStorage.removeItem(key);
        }
      });
      return true;
    } catch (err) {
      console.error("Secure storage clear error:", err);
      return false;
    }
  },

  /**
   * Check if a key exists and is not expired
   */
  hasItem: (key) => {
    return secureStorage.getItem(key) !== null;
  }
};

/**
 * Session Management
 */
export const sessionManager = {
  /**
   * Initialize user session after login
   */
  initSession: (userData) => {
    const { token, role, organizationId, restaurants, restaurantId } = userData;
    
    secureStorage.setItem("authToken", token, 24);
    secureStorage.setItem("userRole", role, 24);
    secureStorage.setItem("sessionStart", Date.now().toString(), 24);
    
    if (organizationId) {
      secureStorage.setItem("organizationId", organizationId, 24);
    }
    
    if (restaurants && restaurants.length > 0) {
      secureStorage.setItem("branches", JSON.stringify(restaurants), 24);
    }
    
    if (restaurantId) {
      secureStorage.setItem("restaurantId", restaurantId, 24);
    }

    // Set session timeout warning (23 hours)
    sessionManager.setSessionTimeout();
  },

  /**
   * Get current session data
   */
  getSession: () => {
    return {
      token: secureStorage.getItem("authToken"),
      role: secureStorage.getItem("userRole"),
      organizationId: secureStorage.getItem("organizationId"),
      restaurantId: secureStorage.getItem("restaurantId"),
      branches: (() => {
        try {
          const branches = secureStorage.getItem("branches");
          return branches ? JSON.parse(branches) : [];
        } catch {
          return [];
        }
      })(),
      sessionStart: secureStorage.getItem("sessionStart")
    };
  },

  /**
   * Check if user is authenticated
   */
  isAuthenticated: () => {
    const token = secureStorage.getItem("authToken");
    const role = secureStorage.getItem("userRole");
    return !!(token && role);
  },

  /**
   * Destroy session and clear all data
   */
  destroySession: () => {
    secureStorage.clear();
    
    // Clear session timeout
    if (sessionManager.timeoutId) {
      clearTimeout(sessionManager.timeoutId);
    }
  },

  /**
   * Set session timeout (auto logout after 24 hours)
   */
  setSessionTimeout: () => {
    // Clear existing timeout
    if (sessionManager.timeoutId) {
      clearTimeout(sessionManager.timeoutId);
    }

    // Set new timeout for 24 hours
    sessionManager.timeoutId = setTimeout(() => {
      sessionManager.destroySession();
      window.location.href = "/login?session=expired";
    }, 24 * 60 * 60 * 1000);
  },

  /**
   * Refresh session (extend expiry)
   */
  refreshSession: () => {
    const session = sessionManager.getSession();
    if (session.token) {
      sessionManager.initSession(session);
    }
  },

  /**
   * Get session duration
   */
  getSessionDuration: () => {
    const sessionStart = secureStorage.getItem("sessionStart");
    if (!sessionStart) return 0;
    
    return Date.now() - parseInt(sessionStart);
  },

  timeoutId: null
};

/**
 * Input Validation Utilities
 */
export const validators = {
  /**
   * Validate email format
   */
  isValidEmail: (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  },

  /**
   * Validate password strength
   */
  isStrongPassword: (password) => {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
    return (
      password.length >= 8 &&
      /[a-z]/.test(password) &&
      /[A-Z]/.test(password) &&
      /\d/.test(password)
    );
  },

  /**
   * Calculate password strength (0-5)
   */
  getPasswordStrength: (password) => {
    let strength = 0;
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (/[a-z]/.test(password) && /[A-Z]/.test(password)) strength++;
    if (/\d/.test(password)) strength++;
    if (/[^a-zA-Z0-9]/.test(password)) strength++;
    return strength;
  },

  /**
   * Sanitize input to prevent XSS
   */
  sanitizeInput: (input) => {
    const div = document.createElement('div');
    div.textContent = input;
    return div.innerHTML;
  }
};

/**
 * CSRF Protection
 */
export const csrfProtection = {
  /**
   * Generate CSRF token
   */
  generateToken: () => {
    const token = Math.random().toString(36).substring(2) + Date.now().toString(36);
    secureStorage.setItem("csrfToken", token, 24);
    return token;
  },

  /**
   * Get CSRF token
   */
  getToken: () => {
    let token = secureStorage.getItem("csrfToken");
    if (!token) {
      token = csrfProtection.generateToken();
    }
    return token;
  },

  /**
   * Get headers with CSRF token
   */
  getHeaders: () => {
    return {
      "Content-Type": "application/json",
      "X-CSRF-Token": csrfProtection.getToken(),
      "X-Requested-With": "XMLHttpRequest"
    };
  }
};

/**
 * API Request Helper with automatic auth headers
 */
export const apiRequest = async (url, options = {}) => {
  const token = secureStorage.getItem("authToken");
  
  const defaultHeaders = {
    "Content-Type": "application/json",
    "X-Requested-With": "XMLHttpRequest"
  };

  if (token) {
    defaultHeaders["Authorization"] = `Bearer ${token}`;
  }

  const config = {
    ...options,
    headers: {
      ...defaultHeaders,
      ...options.headers
    }
  };

  try {
    const response = await fetch(url, config);
    
    // Handle unauthorized
    if (response.status === 401) {
      sessionManager.destroySession();
      window.location.href = "/login?session=unauthorized";
      return null;
    }

    return response;
  } catch (err) {
    console.error("API request error:", err);
    throw err;
  }
};

/**
 * Rate Limiting for login attempts
 */
export const rateLimiter = {
  attempts: {},

  /**
   * Check if action is rate limited
   */
  isLimited: (key, maxAttempts = 5, windowMs = 15 * 60 * 1000) => {
    const now = Date.now();
    const record = rateLimiter.attempts[key];

    if (!record) {
      rateLimiter.attempts[key] = { count: 1, resetTime: now + windowMs };
      return false;
    }

    if (now > record.resetTime) {
      rateLimiter.attempts[key] = { count: 1, resetTime: now + windowMs };
      return false;
    }

    if (record.count >= maxAttempts) {
      return true;
    }

    record.count++;
    return false;
  },

  /**
   * Get remaining time until rate limit reset
   */
  getResetTime: (key) => {
    const record = rateLimiter.attempts[key];
    if (!record) return 0;
    
    const remaining = record.resetTime - Date.now();
    return remaining > 0 ? remaining : 0;
  },

  /**
   * Reset rate limit for a key
   */
  reset: (key) => {
    delete rateLimiter.attempts[key];
  }
};

export default {
  secureStorage,
  sessionManager,
  validators,
  csrfProtection,
  apiRequest,
  rateLimiter
};