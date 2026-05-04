// import { NextResponse } from 'next/server';

// export function middleware(request) {
//   const token = request.cookies.get('token')?.value;
//   const { pathname } = request.nextUrl;

//   // 1. Define protected and public routes
//   const isProtectedRoute = pathname.startsWith('/dashboard');
//   const isPublicRoute = ['/login', '/signup'].includes(pathname);

//   // 2. Redirect to login if trying to access dashboard without token
//   if (isProtectedRoute && !token) {
//     return NextResponse.redirect(new URL('/login', request.url));
//   }

//   // 3. Redirect to dashboard if logged-in user tries to access login/signup
//   if (isPublicRoute && token) {
//     return NextResponse.redirect(new URL('/dashboard/orders', request.url));
//   }

//   return NextResponse.next();
// }

// // Only run middleware on these paths
// export const config = {
//   matcher: ['/dashboard/:path*', '/login', '/signup'],
// };



import { NextResponse } from "next/server";

export function middleware(request) {

  const token = request.cookies.get("token")?.value;

  const { pathname } = request.nextUrl;

  const isDashboardRoute = pathname.startsWith("/dashboard");
  const isAuthRoute = pathname === "/login" || pathname === "/signup";

  /*
  ----------------------------------
  Block dashboard when not logged in
  ----------------------------------
  */

  if (isDashboardRoute && !token) {

    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = "/login";

    return NextResponse.redirect(loginUrl);
  }

  /*
  ----------------------------------
  Prevent logged-in users from login
  ----------------------------------
  */

  if (isAuthRoute && token) {

    const dashboardUrl = request.nextUrl.clone();
    dashboardUrl.pathname = "/dashboard/orders";

    return NextResponse.redirect(dashboardUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/dashboard/:path*",
    "/login",
    "/signup"
  ],
};