enum UserRole {
  worker('Worker', 'Construction worker using tools'),
  manager('Manager', 'Site manager or supervisor'),
  admin('Admin', 'System administrator');

  const UserRole(this.displayName, this.description);

  final String displayName;
  final String description;

  // Helper method to get role from string
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value.toLowerCase(),
      orElse: () => UserRole.worker,
    );
  }

  // Helper method to check if role has admin privileges
  bool get isAdmin => this == UserRole.admin;

  // Helper method to check if role has manager privileges
  bool get isManager => this == UserRole.manager || this == UserRole.admin;

  // Helper method to check if role can manage workers
  bool get canManageWorkers => this == UserRole.manager || this == UserRole.admin;

  // Helper method to check if role can view reports
  bool get canViewReports => this == UserRole.manager || this == UserRole.admin;

  // Helper method to check if role can manage tools
  bool get canManageTools => this == UserRole.manager || this == UserRole.admin;

  // Helper method to get role hierarchy level (higher number = more privileges)
  int get hierarchyLevel {
    switch (this) {
      case UserRole.worker:
        return 1;
      case UserRole.manager:
        return 2;
      case UserRole.admin:
        return 3;
    }
  }

  // Helper method to check if this role can manage another role
  bool canManage(UserRole otherRole) {
    return this.hierarchyLevel > otherRole.hierarchyLevel;
  }

  @override
  String toString() => displayName;
}
