# Add Composer vendor binaries to PATH.
if [[ "$(composer global config bin-dir --absolute 2>/dev/null)" != "" ]]; then
   PATH="${PATH}:$(composer global config bin-dir --absolute 2>/dev/null)";
   export PATH;
fi

