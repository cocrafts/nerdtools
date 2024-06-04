import { isRegistered, register } from '@tauri-apps/plugin-global-shortcut';

export const registerGlobalShortcuts = async () => {
	const switchShortcut = 'Command+Control+Esc';
	const switchRegistered = await isRegistered(switchShortcut);

	if (!switchRegistered) {
		await register(switchShortcut, ({ state }) => {
			if (state === 'Pressed') {
				console.log('Shortcut triggered');
			}
		});
	}
};
