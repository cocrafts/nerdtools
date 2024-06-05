import { type FC, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { invoke } from '@tauri-apps/api/core';
import type { Process } from 'utils/type';

export const App: FC = () => {
	const [message, setMessage] = useState('');
	const onGreet = async () => {
		const remoteMsg: string = await invoke('greet', { name: 'CL' });
		const processes: Process[] = await invoke('process_list');

		console.log(processes);
		setMessage(remoteMsg);
	};

	return (
		<View style={styles.container}>
			<Text style={styles.message} onPress={onGreet}>
				App {message}
			</Text>
		</View>
	);
};

export default App;

const styles = StyleSheet.create({
	container: {
		flex: 1,
		alignItems: 'center',
		justifyContent: 'center',
	},
	message: {
		color: '#FFFFFF',
		fontSize: 18,
	},
});
