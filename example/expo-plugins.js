const { withPodfile } = require('@expo/config-plugins');

const withCustomPodfile = (config) => {
  return withPodfile(config, (config) => {
    const podfileContent = config.modResults.contents;
    
    // Agregar use_modular_headers! al principio del Podfile
    if (!podfileContent.includes('use_modular_headers!')) {
      // Buscar la línea "platform :ios" y agregar use_modular_headers! después
      const platformLine = "platform :ios, podfile_properties['ios.deploymentTarget'] || '15.1'";
      const replacement = `${platformLine}
use_modular_headers!`;
      
      config.modResults.contents = podfileContent.replace(platformLine, replacement);
    }
    
    // fmt 11.x + Xcode 16 / Apple Clang: parche base.h (los -D no aplican en fmt 11.0.2).
    const fmtFixMarker = 'fmt-apple-clang-consteval-patch';
    const legacyFmtMarker = 'fmt-compile-string-fix';
    let contents = config.modResults.contents;
    if (contents.includes(legacyFmtMarker)) {
      contents = contents.replace(
        /\s*# @generated begin fmt-compile-string-fix[\s\S]*?# @generated end fmt-compile-string-fix\n?/,
        '\n',
      );
      config.modResults.contents = contents;
    }
    if (!contents.includes(fmtFixMarker)) {
      const anchor = 'react_native_post_install(';
      const idx = contents.indexOf(anchor);
      if (idx === -1) {
        throw new Error(
          'withCustomPodfile: no se encontró react_native_post_install( en el Podfile; no se pudo aplicar el parche de fmt.',
        );
      }
      const injection = `    # @generated begin ${fmtFixMarker} - expo config plugin
    # fmt 11.x (RCT-Folly): en Apple Clang (Xcode 16) FMT_USE_CONSTEVAL provoca fallo en FMT_STRING.
    # En fmt 11.0.2 los flags -D no respetan FMT_USE_CONSTEVAL; hay que ampliar la condición en base.h.
    fmt_base_h = File.join(installer.sandbox.root, 'fmt/include/fmt/base.h')
    if File.exist?(fmt_base_h)
      source = File.read(fmt_base_h)
      if source.include?('14000029L')
        patched = source.sub(
          '#elif defined(__apple_build_version__) && __apple_build_version__ < 14000029L',
          '#elif defined(__apple_build_version__)'
        )
        File.write(fmt_base_h, patched) if patched != source
      end
    end
    # @generated end ${fmtFixMarker}
    `;
      contents = contents.slice(0, idx) + injection + contents.slice(idx);
      config.modResults.contents = contents;
    }

    return config;
  });
};

module.exports = withCustomPodfile;
