# Contributing to MariaDB ColumnStore Flight Emissions Analytics

Thank you for your interest in contributing! This project aims to be a comprehensive reference implementation for MariaDB ColumnStore optimization.

---

## 🎯 Project Goals

1. **Educational Resource:** Help developers learn ColumnStore optimization
2. **Reference Implementation:** Production-ready patterns for any industry
3. **Performance Excellence:** Demonstrate 20x+ analytical speedups
4. **Community Value:** Reusable code and thorough documentation

---

## 🤝 How to Contribute

### Types of Contributions Welcome

1. **Additional Use Cases**
   - Retail analytics examples
   - Financial services patterns
   - IoT sensor data analysis
   - Healthcare analytics
   - Telecommunications

2. **Query Patterns**
   - New analytical patterns
   - Optimization techniques
   - Edge case handling
   - Performance improvements

3. **Documentation**
   - Clarifications and corrections
   - Additional examples
   - Translations
   - Video tutorials

4. **Performance Benchmarks**
   - Tests on different hardware
   - Larger datasets (1M+, 10M+ records)
   - Cloud platform benchmarks (AWS, Azure, GCP)
   - Bare metal vs virtualized comparisons

5. **Infrastructure**
   - Docker/Kubernetes deployment
   - CI/CD pipelines
   - Automated testing
   - Monitoring and alerting

6. **Bug Fixes**
   - SQL errors
   - Installation script issues
   - Documentation bugs
   - Performance regressions

---

## 🚀 Getting Started

### 1. Fork the Repository

```bash
# Fork on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/mariadb-columnstore-powered-emissions.git
cd mariadb-columnstore-powered-emissions

# Add upstream remote
git remote add upstream https://github.com/ORIGINAL_AUTHOR/mariadb-columnstore-powered-emissions.git
```

### 2. Set Up Development Environment

```bash
# Install dependencies
sudo ./scripts/install_mariadb.sh

# Setup database
./scripts/setup.sh

# Verify installation
mysql -u aviation_user -p flight_emissions -e "SELECT COUNT(*) FROM flights_columnstore;"
```

### 3. Create a Branch

```bash
# Update your fork
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/your-feature-name
# OR
git checkout -b fix/bug-description
```

---

## 📝 Contribution Guidelines

### Code Style

**SQL Code:**
- Use uppercase for SQL keywords: `SELECT`, `FROM`, `WHERE`
- Indent nested queries with 4 spaces
- Add comments explaining business logic
- Include performance notes for complex queries

```sql
-- GOOD EXAMPLE
SELECT 
    dimension_column,
    SUM(metric_column) AS total,
    -- Calculate percentage of grand total
    ROUND(SUM(metric_column) / SUM(SUM(metric_column)) OVER () * 100, 2) AS pct_of_total
FROM columnstore_table
WHERE date_column >= '2024-01-01'
GROUP BY dimension_column
ORDER BY total DESC;

-- BAD EXAMPLE (hard to read)
select dim,sum(met) from tbl where dt>='2024-01-01' group by dim order by sum(met) desc;
```

**Shell Scripts:**
- Use `#!/bin/bash` shebang
- Check for errors: `set -e`
- Add comments for non-obvious commands
- Use meaningful variable names

```bash
#!/bin/bash
set -e  # Exit on error

# Good: Descriptive variable name
database_name="flight_emissions"

# Bad: Unclear abbreviation
db="flight_emissions"
```

### Documentation

**Markdown Files:**
- Use clear headings (H1, H2, H3)
- Include code examples
- Add performance notes where relevant
- Link to related documentation

**Inline Comments:**
- Explain *why*, not *what*
- Include "COPY-PASTE TIP" sections for reusable code
- Add performance expectations

```sql
-- COPY-PASTE TIP: Replace 'department' with any grouping dimension
-- (project_code, cost_center, region, etc.)
-- Expected performance: < 1s on 100K records, < 5s on 1M records
SELECT 
    department,
    SUM(co2_kg) AS total_emissions
FROM flights_columnstore
GROUP BY department;
```

### Testing Requirements

**All contributions must include:**

1. **Functional Testing**
   ```bash
   # Test your SQL query
   mysql -u aviation_user -p flight_emissions < your_new_query.sql
   ```

2. **Performance Testing**
   ```bash
   # Time your query
   SET profiling = 1;
   -- Your query here
   SHOW PROFILES;
   ```

3. **Verification**
   - Query returns expected results
   - Performance is acceptable (< 5s for 100K records)
   - No SQL errors or warnings
   - Documentation is updated

---

## 🎯 Specific Contribution Areas

### 1. Adding a New Use Case

**Steps:**

1. Create file: `examples/04_your_usecase.sql`
2. Include 5-6 queries demonstrating different patterns
3. Add comprehensive comments
4. Test all queries
5. Document in README.md

**Template:**

```sql
-- =====================================================================
-- [YOUR USE CASE NAME]
-- =====================================================================
-- Purpose: [Brief description]
-- Target Audience: [Who will use this]
-- Performance: [Expected query times]
-- =====================================================================

USE flight_emissions;

-- ---------------------------------------------------------------------
-- QUERY 1: [Descriptive Name]
-- ---------------------------------------------------------------------
-- Business Need: [Why this query matters]
-- ColumnStore Advantage: [What makes it fast]
-- Expected Runtime: [X seconds]

SELECT 
    [your columns]
FROM [your tables]
WHERE [your conditions]
GROUP BY [your dimensions]
ORDER BY [your sort];

-- COPY-PASTE TIP: [How to adapt for other industries]

-- [Add 4-5 more queries following same pattern]
```

### 2. Adding a Query Pattern

**Steps:**

1. Edit `docs/QUERY_PATTERN_LIBRARY.md`
2. Add new section with:
   - Pattern name and number
   - Generic template
   - aviation-specific example
   - When to use
   - ColumnStore advantages
   - Performance notes

**Template:**

```markdown
## X. [Pattern Name]

### Pattern Template
[Generic SQL template]

### Flight Example
[Concrete example from project]

### When to Use
- [Use case 1]
- [Use case 2]

### ColumnStore Advantages
- [Advantage 1]
- [Advantage 2]
```

### 3. Performance Benchmarks

**Steps:**

1. Document your hardware setup
2. Run benchmarks using `./scripts/benchmark.sh`
3. Record results in `benchmarks/results/YYYY-MM-DD_hardware_description.txt`
4. Add summary to `docs/BENCHMARK_RESULTS.md`

**Format:**

```
Hardware: [CPU model, RAM, disk type]
OS: [Operating system version]
MariaDB: [Version]
Dataset Size: [Number of records]

Results:
Query 1: [X seconds]
Query 2: [Y seconds]
...
```

### 4. Documentation Improvements

**Welcome contributions:**
- Fixing typos and grammar
- Clarifying confusing sections
- Adding diagrams and visualizations
- Translating to other languages
- Creating video tutorials

---

## 🔍 Code Review Process

### What We Look For

1. **Correctness**
   - SQL queries execute without errors
   - Results are accurate
   - Edge cases handled

2. **Performance**
   - Queries complete in reasonable time
   - ColumnStore features utilized
   - No obvious optimizations missed

3. **Code Quality**
   - Clear, readable code
   - Consistent style
   - Comprehensive comments
   - No hardcoded values

4. **Documentation**
   - README updated if needed
   - Inline comments added
   - Performance notes included

### Review Timeline

- Small fixes (typos, documentation): 1-2 days
- New queries/patterns: 3-5 days
- Major features: 1-2 weeks

---

## 📋 Pull Request Checklist

Before submitting, ensure:

- [ ] Code follows style guidelines
- [ ] All queries tested and working
- [ ] Performance is acceptable
- [ ] Documentation updated
- [ ] Comments added/updated
- [ ] No debugging code left in
- [ ] Commit messages are clear
- [ ] Branch is up to date with main

### Commit Message Format

```
[type]: Brief description (50 chars max)

Longer explanation if needed (wrap at 72 characters).
Include motivation for change and contrast with previous behavior.

Fixes #123
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `perf`: Performance improvement
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

**Examples:**
```
feat: Add retail analytics use case with 6 queries

Demonstrates how aviation patterns translate to retail domain.
Includes sales analysis, inventory optimization, and customer
segmentation queries.

docs: Clarify partition pruning setup in optimization guide

Added step-by-step partition creation commands and common
troubleshooting tips based on user feedback.

perf: Optimize route aggregation query using CTE

Reduced query time from 3.2s to 1.1s by materializing
intermediate results. Tested on 100K records.
```

---

## 🐛 Reporting Bugs

### Before Reporting

1. Search existing issues
2. Verify you're on latest version
3. Test on clean installation
4. Collect relevant information

### Bug Report Template

```markdown
**Describe the bug**
Clear description of what's wrong.

**To Reproduce**
Steps to reproduce:
1. Run command '...'
2. Execute query '...'
3. See error

**Expected behavior**
What you expected to happen.

**Actual behavior**
What actually happened.

**Environment**
- OS: [e.g., Ubuntu 22.04]
- MariaDB Version: [e.g., 11.4.0]
- ColumnStore Version: [e.g., 6.4.2]
- Hardware: [CPU, RAM]

**Additional context**
Error messages, logs, screenshots, etc.
```

---

## 💡 Feature Requests

### Before Requesting

1. Check if feature exists
2. Search existing feature requests
3. Consider if it fits project scope

### Feature Request Template

```markdown
**Is your feature request related to a problem?**
Clear description of the problem.

**Describe the solution you'd like**
What you want to happen.

**Describe alternatives you've considered**
Other approaches you thought about.

**Additional context**
Mockups, examples, references, etc.
```

---

## 🎓 Learning Resources

### ColumnStore Documentation
- [Official MariaDB ColumnStore Docs](https://mariadb.com/kb/en/columnstore/)
- [Window Functions Guide](https://mariadb.com/kb/en/window-functions/)
- [Partitioning Overview](https://mariadb.com/kb/en/partitioning-types/)

### SQL Best Practices
- [SQL Style Guide](https://www.sqlstyle.guide/)
- [Query Optimization Techniques](https://mariadb.com/kb/en/optimization-and-indexes/)

### Project-Specific
- [Query Pattern Library](docs/QUERY_PATTERN_LIBRARY.md)
- [Optimization Guide](docs/COLUMNSTORE_OPTIMIZATION_GUIDE.md)
- [Architecture Overview](docs/ARCHITECTURE.md)

---

## 🏆 Recognition

Contributors will be:
- Listed in project README
- Acknowledged in release notes
- Mentioned in presentations/blog posts

---

## 📞 Getting Help

**Stuck? Need guidance?**

- Open a [GitHub Discussion](#)
- Email: [kapil.verma.dev1@gmail.com](#)
- MariaDB Slack: [#columnstore channel](#)

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to making this the best MariaDB ColumnStore reference implementation!** 🚀


We welcome contributions! Areas for improvement:
- Additional use cases (retail, finance, IoT)
- More query patterns
- Performance benchmarks on different hardware
- Documentation improvements