set -e

# Skip during indexing phase in XCode 13+
if [ "$ACTION" == "indexbuild" ]; then
	echo "Not building *.udl files during indexing."
	exit 0
fi

# Skip for preview builds
if [ "$ENABLE_PREVIEWS" = "YES" ]; then
	echo "Not building *.udl files during preview builds."
	exit 0
fi

cd "${INPUT_FILE_DIR}/.."
"${BUILD_DIR}/debug/uniffi-bindgen" generate "src/${INPUT_FILE_NAME}" --language swift --out-dir "${PROJECT_DIR}/generated"
