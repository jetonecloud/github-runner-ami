output "launch_template_id" {
  value = module.github_runner.launch_template_id
}

output "autoscaling_group_name" {
  value = module.github_runner.autoscaling_group_name
}

output "iam_role_arn" {
  value = module.github_runner.iam_role_arn
}
