

resource "aws_budgets_budget" "monthly_20_usd" {
  name         = "Monthly-20-USD"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = "20"
  limit_unit   = "USD"

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.admin_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "FORECASTED"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.admin_email]
  }
}