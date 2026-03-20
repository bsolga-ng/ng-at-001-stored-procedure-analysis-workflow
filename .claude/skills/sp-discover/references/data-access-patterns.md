# .NET Data Access Patterns for SP Detection

Reference patterns for identifying stored procedure calls in .NET codebases.

## ADO.NET

```csharp
// Pattern 1: CommandType + CommandText
cmd.CommandType = CommandType.StoredProcedure;
cmd.CommandText = "schema.SpName";

// Pattern 2: Constructor
var cmd = new SqlCommand("schema.SpName", connection);
cmd.CommandType = CommandType.StoredProcedure;

// Pattern 3: Inline EXEC
cmd.CommandText = "EXEC schema.SpName @param1, @param2";
```

## Dapper

```csharp
// Pattern 1: Query with CommandType
connection.Query<T>("schema.SpName", parameters, commandType: CommandType.StoredProcedure);

// Pattern 2: Execute
connection.Execute("schema.SpName", parameters, commandType: CommandType.StoredProcedure);

// Pattern 3: QueryFirstOrDefault
connection.QueryFirstOrDefault<T>("schema.SpName", parameters, commandType: CommandType.StoredProcedure);

// Pattern 4: QueryMultiple
connection.QueryMultiple("schema.SpName", parameters, commandType: CommandType.StoredProcedure);
```

## Entity Framework

```csharp
// Pattern 1: FromSqlRaw
context.Set<T>().FromSqlRaw("EXEC schema.SpName @p0, @p1", param0, param1);

// Pattern 2: ExecuteSqlRaw
context.Database.ExecuteSqlRaw("EXEC schema.SpName @p0, @p1", param0, param1);

// Pattern 3: FromSqlInterpolated
context.Set<T>().FromSqlInterpolated($"EXEC schema.SpName {param0}, {param1}");
```

## Constants / Enums

```csharp
// Pattern 1: String constants
public static class StoredProcedures
{
    public const string GetJobsForSync = "DataSync.GetJobsForSync";
}

// Pattern 2: Enum with attribute
[StoredProcedure("DataSync.GetJobsForSync")]
GetJobsForSync,
```

## SQL Definition Files

```sql
-- Pattern: CREATE/ALTER in .sql files or migrations
CREATE PROCEDURE [schema].[SpName]
ALTER PROCEDURE [schema].[SpName]
```

## Grep Patterns for Detection

```
CommandType\.StoredProcedure
SqlCommand\s*\(
\.Query<.*>\(\"
\.Execute\(\"
\.FromSqlRaw\(\"
\.ExecuteSqlRaw\(\"
CREATE\s+PROCEDURE
ALTER\s+PROCEDURE
EXEC\s+\[?\w+\]?\.\[?\w+\]?
```
