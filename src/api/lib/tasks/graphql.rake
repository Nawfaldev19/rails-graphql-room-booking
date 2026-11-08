namespace :graphql do
  desc "Write the GraphQL schema to schema.graphql at the project root, for the web app's types"
  task schema: :environment do
    target = Rails.root.join("../../schema.graphql")
    target.write(RoomBookingSchema.to_definition)
    puts "Wrote #{target.relative_path_from(Rails.root)}"
  end
end
