//const apiConfig = {
 // BASE_URL: process.env.NEXT_PUBLIC_API_URL || "http://localhost:5000",
//};

//export default apiConfig;
//

const BASE_URL =
  process.env.NEXT_PUBLIC_API_URL ||
  "https://scanserve.in" 
  // "http://localhost:5000";

const apiConfig = {
  BASE_URL,
};

export default apiConfig;
