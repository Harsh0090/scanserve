  // // // // socket.j/s
  
  // // // import { io } from "socket.io-client";
  
  // // // let socket;
  
  // // // export const getSocket = (restaurantId) => {
  
  // // //   if (!socket) {
  
  // // //     socket = io("http://localhost:5000", {
  // // //       auth: { restaurantId },
  // // //     });
  
  // // //   }
  
  // // //   return socket;
  // // // };
  
  
  // // import { io } from "socket.io-client";
  // // import apiConfig from "@/utils/apiConfig";
  
  // // let socket;
  
  // // export const getSocket = (restaurantId) => {
  // //   if (!socket) {
  // //     socket = io(apiConfig?.BASE_URL, {
  // //       withCredentials: true,
  // //       auth: { restaurantId }
  // //     });
  // //   }
  
  // //   return socket;
  // // };
  
  // // export const disconnectSocket = () => {
  // //   if (socket) {
  // //     socket.disconnect();
  // //     socket = null;
  // //   }
  // // };
  
  // // Frontend/lib/socket.js
  // import { io } from "socket.io-client";
  // import apiConfig from "@/utils/apiConfig";
  
  // let socket;
  
  // export const getSocket = (restaurantId) => {
  //   if (!socket) {
  // console.log("socket data")
  //     socket = io(apiConfig.BASE_URL, {
  
  //       transports: ["websocket"],   // IMPORTANT: disable polling
  //       path: "/socket.io",          // match nginx route
  //       withCredentials: true,
  
  //       auth: {
  //         restaurantId
  //       }
  
  //     });
  
  //     socket.on("connect", () => {
  //       console.log("Socket bhaiiiiiiiiiiiii connected:", socket.id);
  //     });
  
  //     socket.on("disconnect", () => {
  //       console.log("Socket bhai disconnected");
  //     });
  
  //   }
  
  //   return socket;
  // };
  
  // export const disconnectSocket = () => {
  //   if (socket) {
  //     socket.disconnect();
  //     socket = null;
  //   }
  // };
  


  // Frontend/lib/socket.js

import { io } from "socket.io-client";
import apiConfig from "@/utils/apiConfig";

let socket;

export const getSocket = (restaurantId) => {

  if (!socket) {

    socket = io(apiConfig.BASE_URL, {

      transports: ["websocket"],
      path: "/socket.io",
      withCredentials: true,

      auth: {
        restaurantId
      },

      // 🔥 important for reliability
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 2000,
      timeout: 20000

    });

    socket.on("connect", () => {
      console.log("✅ Socket connected:", socket.id);
    });

    socket.on("disconnect", (reason) => {
      console.log("❌ Socket disconnected:", reason);
    });

    socket.on("reconnect_attempt", () => {
      console.log("🔄 Trying to reconnect socket...");
    });

  }

  return socket;
};

export const disconnectSocket = () => {

  if (socket) {
    socket.disconnect();
    socket = null;
  }

};