/**
 * App root — handles Firebase auth state and renders Dashboard.
 */

import React, { useEffect, useState } from 'react';
import Dashboard from './Dashboard';

const PRIMARY  = '#085041';
const SURFACE  = '#F7F5EF';
const BORDER   = '#D3D1C7';

export default function App() {
  // In production, use Firebase Auth:
  // const [user, setUser] = useState(null);
  // useEffect(() => {
  //   import { getAuth, onAuthStateChanged } from 'firebase/auth';
  //   return onAuthStateChanged(getAuth(), setUser);
  // }, []);

  // For demo: skip auth — show dashboard directly.
  const demoToken = 'DEMO_MODE';

  return <Dashboard idToken={demoToken} />;
}
