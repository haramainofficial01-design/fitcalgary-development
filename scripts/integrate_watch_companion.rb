#!/usr/bin/env ruby

require "xcodeproj"

root = File.expand_path("..", __dir__)
project_path = File.join(root, "apps/fitcalgary_app/ios/Runner.xcodeproj")
pubspec_path = File.join(root, "apps/fitcalgary_app/pubspec.yaml")
version_value = File.readlines(pubspec_path).find { |line| line.start_with?("version:") }&.split&.last
abort "Flutter version is missing from pubspec.yaml" unless version_value&.include?("+")
build_name, build_number = version_value.split("+", 2)
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == "Runner" }
abort "Runner target not found" unless runner

watch = project.targets.find { |target| target.name == "FitCalgaryWatch" }
unless watch
  watch = project.new_target(:application, "FitCalgaryWatch", :watchos, "10.0")
  group = project.main_group.new_group("FitCalgaryWatch", "../../watch/FitCalgaryWatch")
  swift_files = %w[
    FitCalgaryWatchApp.swift
    Models/WatchSnapshot.swift
    Services/KeychainStore.swift
    Services/WatchStore.swift
    Views/DashboardView.swift
    Views/GlassCard.swift
  ].map { |path| group.new_file(path) }
  watch.add_file_references(swift_files)
  assets = group.new_file("Resources/Assets.xcassets")
  watch.resources_build_phase.add_file_reference(assets, true)

  watch.build_configurations.each do |configuration|
    release = configuration.name == "Release"
    configuration.build_settings.merge!(
      "ASSETCATALOG_COMPILER_APPICON_NAME" => "AppIcon",
      "CODE_SIGN_ENTITLEMENTS" => "../../watch/FitCalgaryWatch/FitCalgaryWatch.entitlements",
      "CODE_SIGN_STYLE" => "Automatic",
      "CURRENT_PROJECT_VERSION" => "$(FLUTTER_BUILD_NUMBER)",
      "GENERATE_INFOPLIST_FILE" => "YES",
      "INFOPLIST_KEY_CFBundleDisplayName" => "FitCalgary",
      "INFOPLIST_KEY_NSAppTransportSecurity_NSAllowsArbitraryLoads" => "NO",
      "INFOPLIST_KEY_WKCompanionAppBundleIdentifier" => "ca.fitcalgary.index",
      "MARKETING_VERSION" => "$(FLUTTER_BUILD_NAME)",
      "PRODUCT_BUNDLE_IDENTIFIER" => "ca.fitcalgary.index.watchkitapp",
      "PRODUCT_NAME" => "FitCalgary",
      "SDKROOT" => "watchos",
      "SKIP_INSTALL" => "YES",
      "SWIFT_VERSION" => "6.0",
      "TARGETED_DEVICE_FAMILY" => "4",
      "WATCHOS_DEPLOYMENT_TARGET" => "10.0",
      "APS_ENVIRONMENT" => release ? "production" : "development",
    )
  end

  runner.add_dependency(watch)
  embed = runner.new_copy_files_build_phase("Embed Watch Content")
  embed.dst_subfolder_spec = "1"
  embed.dst_path = "Watch"
  build_file = embed.add_file_reference(watch.product_reference, true)
  build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
end

watch.build_configurations.each do |configuration|
  configuration.build_settings["MARKETING_VERSION"] = build_name
  configuration.build_settings["CURRENT_PROJECT_VERSION"] = build_number
  configuration.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
  configuration.build_settings["INFOPLIST_FILE"] = "../../watch/FitCalgaryWatch/Info.plist"
end

# Flutter's Thin Binary phase mutates the assembled Runner bundle. Embed the
# Watch app first so Xcode does not infer a dependency cycle through Info.plist.
embed = runner.copy_files_build_phases.find { |phase| phase.name == "Embed Watch Content" }
thin = runner.shell_script_build_phases.find { |phase| phase.name == "Thin Binary" }
if embed && thin
  embed.dst_subfolder_spec = "1"
  embed.dst_path = "Watch"
  runner.build_phases.delete(embed)
  runner.build_phases.insert(runner.build_phases.index(thin), embed)
end

unless runner.shell_script_build_phases.any? { |phase| phase.name == "Validate Production Release Configuration" }
  phase = runner.new_shell_script_build_phase("Validate Production Release Configuration")
  phase.shell_path = "/bin/sh"
  phase.shell_script = <<~'SH'
    if [ "$CONFIGURATION" = "Release" ]; then
      case "${FITCALGARY_ASSOCIATED_DOMAIN:-}" in
        ""|*localhost*|*.invalid|*://*|*/*)
          echo "error: FITCALGARY_ASSOCIATED_DOMAIN must be an explicit production domain for Release builds."
          exit 1
          ;;
      esac
    fi
  SH
  runner.build_phases.delete(phase)
  runner.build_phases.unshift(phase)
end

project.save
puts "FitCalgaryWatch is embedded in Runner with fail-closed Release validation."
