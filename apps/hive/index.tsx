import type { FC } from 'react';
import { StyleSheet, Text, View } from 'react-native';

export const App: FC = () => {
	return (
		<View style={styles.container}>
			<Text>App</Text>
		</View>
	);
};

export default App;

const styles = StyleSheet.create({
	container: {
		flex: 1,
	},
});
