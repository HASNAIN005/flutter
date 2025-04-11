# This is a generated file; do not edit or check into version control.

require 'json'

def parse_KV_file(file, separator = '=')
    file_abs_path = File.expand_path(file)
    return {} unless File.exist?(file_abs_path)
    map = {}
    File.foreach(file_abs_path) do |line|
        key, value = line.strip.split(separator, 2)
        map[key] = value
    end
    map
end

def flutter_root
    generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
    unless File.exist?(generated_xcode_build_settings_path)
        raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure `flutter pub get` is executed first."
    end
    File.dirname(File.dirname(generated_xcode_build_settings_path))
end

def flutter_ios_podfile_setup
    generated_pod_config_path = File.join(flutter_root, '.ios', 'Flutter', 'pod_config.json')
    return unless File.exist?(generated_pod_config_path)
    pod_config = File.read(generated_pod_config_path)
    pod_config_json = JSON.parse(pod_config)
    pod_config_json['pod_disables'].each do |pod_disable|
        Pod::Spec.new do |s|
            s.name = pod_disable
            s.version = '1.0.0'
        end
    end
end

def install_all_flutter_pods(installer)
    flutter_application_path = File.join(flutter_root, 'example')
    symlink_flutter_application(flutter_application_path)

    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            flutter_generated_configurations.each do |key, value|
                next unless value
                config.build_settings[key] ||= value
            end
        end
    end
end

def symlink_flutter_application(flutter_application_path)
    return unless File.exist?(flutter_application_path)
    app_symlink_path = File.join(flutter_application_path, "project_file")
    FileUtils.mkdir_p(folders_abs_paths_to_remove) if folders_abs_paths_to_remove && Dir.empty?(folders_abs_paths_to_remove)
end