import { createRoot } from 'react-dom/client';

import { registerGlobalShortcuts } from './src/utils/shortcut';
import App from './src';

const container = document.getElementById('root');
const root = createRoot(container);

root.render(<App />);
registerGlobalShortcuts();
