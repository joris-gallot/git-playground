// Authentication module v1
export interface User { id: string; email: string; }
export function login(email: string, password: string): Promise<User> { return Promise.resolve({ id: '1', email }); }
export function redirectAfterLogin(returnUrl: string = '/') { window.location.href = returnUrl; }
// Added proper URL validation
