default_platform(:ios)
$upload_retry=0

platform :ios do
  desc "Push a new beta build to TestFlight"

  lane :do_build do
    build_app(
      skip_build_archive: true,
      archive_path: "../build/ios/archive/Runner.xcarchive",
    )
  end

  lane :do_upload do
    changelog = read_changelog(changelog_path: '../CHANGELOG.md')

    begin
      upload_to_testflight(
        skip_waiting_for_build_processing: true,
        changelog: changelog,
      )
    rescue => ex
         $upload_retry +=1
         if $upload_retry <= 3
           do_upload
         else
           raise ex
         end
     end
  end
end
