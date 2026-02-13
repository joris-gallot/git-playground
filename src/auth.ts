// Authentication module v1
export interface User { id: string; email: string; }
export function login(email: string, password: string): Promise<User> { return Promise.resolve({ id: '1', email }); }
