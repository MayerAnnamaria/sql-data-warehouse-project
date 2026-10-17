# Data Warehouse and Analytics Project

The materials of the data warehouse project: the source files, and the docs.

You take raw files from two systems, a CRM and an ERP, and build one data warehouse in SQL Server. At the end, the data is clean and ready for analysis.

**New here? Open the setup guide in the `00_setup` folder.** It walks you through installing SQL Server and creating the database, on Windows and Mac, with the fixes for the common errors.

```
sql-data-warehouse-project/
├── 00_setup/               the setup guide, and the one-click Docker start for Mac
├── 01_datasets/            the six source files the project loads
│   ├── source_crm/         three files from the CRM system
│   └── source_erp/         three files from the ERP system
├── 02_docs/                the requirements, the diagrams and the notes
├── 03_scripts/             the project scripts, in the order of the videos
│   ├── init_database.sql   creates the database: run it first
│   ├── bronze/             loads the raw files
│   ├── silver/             cleans and prepares the data
│   └── gold/               builds the tables for analysis
└── 04_tests/               checks the quality of the silver and gold data
```

The project reads the six files from `C:\sql\dwh_project\01_datasets\`. Put the folder there, or change the six paths in `03_scripts/bronze/proc_load_bronze.sql`. The videos show the folders without numbers: `datasets` there is `01_datasets` here, `scripts` is `03_scripts`.

---
## 🏗️ Data Architecture

The data architecture for this project follows Medallion Architecture **Bronze**, **Silver**, and **Gold** layers:
![Data Architecture](02_docs/data_architecture.png)

1. **Bronze Layer**: Stores raw data as-is from the source systems. Data is ingested from CSV Files into SQL Server Database.
2. **Silver Layer**: This layer includes data cleansing, standardization, and normalization processes to prepare data for analysis.
3. **Gold Layer**: Houses business-ready data modeled into a star schema required for reporting and analytics.

---
## 📖 Project Overview

In this project, you:

1. **Design the architecture:** a modern data warehouse with three layers, bronze, silver and gold.
2. **Build the ETL pipelines:** load the source files and move the data through the layers.
3. **Model the data:** facts and dimensions, ready for reports.
4. **Analyze it:** answer business questions with SQL.

---

## 🛠️ Important Links & Tools

- **SQL Server and SSMS:** the setup guide in `00_setup` has the links and every step.
- **[Git](https://github.com/):** a GitHub account, to save and share your project.
- **[draw.io](https://www.drawio.com/):** to draw the architecture and the data model.
- **[Notion template](https://www.notion.com/templates/sql-data-warehouse-project):** the project plan, ready to copy.
- **[Notion project steps](https://thankful-pangolin-2ca.notion.site/SQL-Data-Warehouse-Project-16ed041640ef80489667cfe2f380b269?pvs=4):** every phase and task of the project.

---

## 🚀 Project Requirements

### Building the Data Warehouse (Data Engineering)

#### Objective
Develop a modern data warehouse using SQL Server to consolidate sales data, enabling analytical reporting and informed decision-making.

#### Specifications
- **Data Sources**: Import data from two source systems (ERP and CRM) provided as CSV files.
- **Data Quality**: Cleanse and resolve data quality issues prior to analysis.
- **Integration**: Combine both sources into a single, user-friendly data model designed for analytical queries.
- **Scope**: Focus on the latest dataset only; historization of data is not required.
- **Documentation**: Provide clear documentation of the data model to support both business stakeholders and analytics teams.

---

### BI: Analytics & Reporting (Data Analysis)

#### Objective
Develop SQL-based analytics to deliver detailed insights into:
- **Customer Behavior**
- **Product Performance**
- **Sales Trends**

These insights empower stakeholders with key business metrics, enabling strategic decision-making.  

---
## 🌟 About me

Hi, I'm **Annamaria Mayer**. I have a background in IT project coordination, software testing, and data analysis, with experience supporting software development projects in international environments. I hold a Master's degree in Sociology, which has provided me with a strong foundation in research methods, statistics, and analytical thinking. I'm currently expanding my technical skills in **SQL Server, Python, and data warehousing**, with a focus on turning data into meaningful insights and practical business solutions.

## 🛡️ License

## Credits and Attribution

This project is based on the [SQL Data Warehouse Project](https://github.com/DataWithBaraa/sql-data-warehouse-project) created by **Baraa Khatib Salkini (DataWithBaraa)**.

The original project is licensed under the [MIT License](https://github.com/DataWithBaraa/sql-data-warehouse-project/blob/main/LICENSE).

I am using this project to develop and demonstrate my practical skills in SQL Server, data warehousing, ETL processes, data transformation, and data quality testing.

All credit for the original project structure, datasets, and learning materials belongs to the original author.

