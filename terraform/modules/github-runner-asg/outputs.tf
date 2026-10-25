output "launch_template_id" {
  description = "ID of the launch template. Pass this to an EC2 Fleet / RunInstances-based scale-out Lambda if you drive capacity outside the ASG (see docs/architecture.md)."
  value       = aws_launch_template.runner.id
}

output "launch_template_latest_version" {
  description = "Latest version number of the launch template."
  value       = aws_launch_template.runner.latest_version
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group. Used by a scale-out Lambda calling autoscaling:SetDesiredCapacity."
  value       = aws_autoscaling_group.runner.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.runner.arn
}

output "iam_role_arn" {
  description = "ARN of the runner instance role."
  value       = aws_iam_role.runner.arn
}

output "iam_role_name" {
  description = "Name of the runner instance role."
  value       = aws_iam_role.runner.name
}

output "iam_instance_profile_name" {
  description = "Name of the instance profile (needed if a scale-out Lambda launches instances directly via RunInstances/CreateFleet instead of the launch template reference)."
  value       = aws_iam_instance_profile.runner.name
}
