import axios from "axios";
import apiConfig from "./apiConfig";

const api = axios.create({
  baseURL: apiConfig?.BASE_URL,
  withCredentials: true,
});

/*
 🔥 GLOBAL RESPONSE INTERCEPTOR
*/
api.interceptors.response.use(
  (response) => response,
  (error) => {

    const data = error?.response?.data;

    if (data?.code === "TRIAL_EXPIRED") {

      window.dispatchEvent(
        new CustomEvent("trialExpired")
      );

    }

    return Promise.reject(error);
  }
);

export default api;