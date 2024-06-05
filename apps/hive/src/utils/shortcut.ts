import { invoke } from '@tauri-apps/api/core';
import { isRegistered, register } from '@tauri-apps/plugin-global-shortcut';
import type { Process } from 'utils/type';

let previousFocus: Process;
const wezterm: Process = {
	id: 'com.github.wez.wezterm',
	name: 'WezTerm',
	focused: false,
};

export const registerGlobalShortcuts = async () => {
	const switchShortcut = 'Command+Control+Esc';
	const switchRegistered = await isRegistered(switchShortcut);

	if (!switchRegistered) {
		await register(switchShortcut, async ({ state }) => {
			if (state === 'Pressed') {
				const focusing: Process = await invoke('get_focused_application');

				if (focusing.name === wezterm.name && previousFocus) {
					await invoke('set_focused_application', { process: previousFocus });
				} else if (focusing.name !== wezterm.name) {
					previousFocus = focusing;
					await invoke('set_focused_application', { process: wezterm });
				}
			}
		});
	}
};
