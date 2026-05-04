


/**
 * Centralized Auth Management
 * Storing data as a single JSON object is cleaner and easier to clear on logout.
 */
export const saveAuthSession = (data) => {
  if (typeof window !== "undefined") {
    const sessionData = {
      token: data.token,
      role: data.role,
      // Fallbacks to ensure ID is always present regardless of role response
      restaurantId: data.restaurants?.[0]?._id || data.restaurantId || null,
      organizationId: data.organizationId || data.restaurants?.[0]?.organization || null,
      userName: data.name || "Admin"
    };
    localStorage.setItem("qr_serve_session", JSON.stringify(sessionData));
  }
};

export const getAuthSession = () => {
  if (typeof window !== "undefined") {
    const session = localStorage.getItem("qr_serve_session");
    return session ? JSON.parse(session) : null;
  }
  return null;
};

export const clearAuthSession = () => {
  localStorage.removeItem("qr_serve_session");
  window.location.href = "/login";
};