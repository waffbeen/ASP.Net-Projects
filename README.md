# Vision – ASP.NET Web Forms Project

This is a fully working **ASP.NET Web Forms** project developed with **VB.NET** in Visual Studio.  
It contains multiple modules, pages, and a SQL Server database backend with tables for sales data, reports, users, and queries.
in this project you can simply drilling data via your data source means you don't have to learn sql for joins, groupby just simply connect w your database
and use this project instead 
if you're dealing with what is drill down in data , simply understand a simply chart is shwoing years production just click on any part of chart now you can 
enter that year and now chart and data showing is placed into that year and showing months instead of years 
if you have any queries related to this project just dm me - insta id is in eof 
---

## 🔧 Project Setup

### 1. Clone the Repository

```bash
git clone https://github.com/waffbeen/ASP.Net-Projects.git
2. Open in Visual Studio
Open Vision.sln in Visual Studio 2022 or later.

Ensure you have .NET Framework 4.7+ installed.

Restore NuGet packages if needed.

3. Database Setup
Use SQL Server Management Studio (SSMS) or Azure Data Studio.

Execute the SQL script below to create all necessary tables and constraints in your database.

USE [Vision]
GO

/****** Table: AmazonSalesData ******/
CREATE TABLE [dbo].[AmazonSalesData](
	  NOT NULL,
	[Branch] [nvarchar](max) NULL,
	  NULL,
	[Customer_type] [nvarchar](max) NULL,
	[Gender] [nvarchar](max) NULL,
	  NULL,
	[Unit_price] [decimal](18, 10) NULL,
	[Quantity] [tinyint] NULL,
	[Tax_5] [decimal](18, 10) NULL,
	[Total] [decimal](18, 10) NULL,
	[Date] [date] NULL,
	  NULL,
	  NULL,
	[cogs] [decimal](18, 10) NULL,
	[gross_margin_percentage] [decimal](18, 10) NULL,
	[gross_income] [decimal](18, 10) NULL,
	[Rating] [decimal](18, 10) NULL,
	[OrderDate]  AS (CONVERT([datetime],[Date])+CONVERT([datetime],[Time])) PERSISTED,
	[OrderID] [int] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_AmazonSalesData_OrderID] PRIMARY KEY CLUSTERED 
(
	[OrderID] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
  ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Table: DrillDownQueries ******/
CREATE TABLE [dbo].[DrillDownQueries](
	[DrillDownQueryID] [int] IDENTITY(1,1) NOT NULL,
	[ReportID] [int] NULL,
	[DrillLevel] [int] NOT NULL,
	  NOT NULL,
	[SQLQuerySnippet] [nvarchar](max) NOT NULL,
	  NULL,
PRIMARY KEY CLUSTERED 
(
	[DrillDownQueryID] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
  ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UC_ReportLevelQueryName] UNIQUE NONCLUSTERED 
(
	[ReportID] ASC,
	[DrillLevel] ASC,
	[QueryName] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
  ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Table: QueryTemplates ******/
CREATE TABLE [dbo].[QueryTemplates](
	[TemplateID] [int] IDENTITY(1,1) NOT NULL,
	  NOT NULL,
	[Description] [nvarchar](max) NULL,
	[SQLQueryTemplate] [nvarchar](max) NOT NULL,
	[CreatedBy] [int] NULL,
	[CreatedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[TemplateID] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
  ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[TemplateName] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
  ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Table: ReportVersions ******/
CREATE TABLE [dbo].[ReportVersions](
	[VersionID] [int] IDENTITY(1,1) NOT NULL,
	[ReportID] [int] NULL,
	[SQLQuery] [nvarchar](max) NOT NULL,
	[SavedBy] [int] NULL,
	[SavedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[VersionID] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
  ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Table: SavedReports ******/
CREATE TABLE [dbo].[SavedReports](
	[ReportID] [int] IDENTITY(1,1) NOT NULL,
	  NOT NULL,
	[SQLQuery] [nvarchar](max) NOT NULL,
	  NULL,
	[CreatedBy] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[LastModified] [datetime] NULL,
	[AllowedUsers] [nvarchar](max) NULL,
	[IsNew] [bit] NULL,
	[PublishedDate] [datetime] NULL,
	[ReportDescription] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[ReportID] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
  ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[ReportName] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
  ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Table: Users ******/
CREATE TABLE [dbo].[Users](
	[UserID] [int] IDENTITY(1,1) NOT NULL,
	  NOT NULL,
	  NOT NULL,
	  NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[UserID] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
  ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Username] ASC
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
  ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[QueryTemplates] ADD  DEFAULT (getdate()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[ReportVersions] ADD  DEFAULT (getdate()) FOR [SavedDate]
GO
ALTER TABLE [dbo].[SavedReports] ADD  DEFAULT (getdate()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[SavedReports] ADD  DEFAULT (getdate()) FOR [LastModified]
GO
ALTER TABLE [dbo].[SavedReports] ADD  DEFAULT ((1)) FOR [IsNew]
GO

ALTER TABLE [dbo].[DrillDownQueries]  WITH CHECK ADD FOREIGN KEY([ReportID])
REFERENCES [dbo].[SavedReports] ([ReportID])
GO

ALTER TABLE [dbo].[QueryTemplates]  WITH CHECK ADD FOREIGN KEY([CreatedBy])
REFERENCES [dbo].[Users] ([UserID])
GO

ALTER TABLE [dbo].[ReportVersions]  WITH CHECK ADD FOREIGN KEY([ReportID])
REFERENCES [dbo].[SavedReports] ([ReportID])
GO

ALTER TABLE [dbo].[ReportVersions]  WITH CHECK ADD FOREIGN KEY([SavedBy])
REFERENCES [dbo].[Users] ([UserID])
GO

ALTER TABLE [dbo].[SavedReports]  WITH CHECK ADD FOREIGN KEY([CreatedBy])
REFERENCES [dbo].[Users] ([UserID])
GO


Project Structure
Vision/
├── Creator.aspx
├── Viewer.aspx
├── Site.Master
├── Core/               # Business logic
├── Hub/                # Additional modules
├── Scripts/            # JavaScript files
├── Logs/               # Log files
├── App_Data/           # Local database or data files
├── README.md           # This file
└── Vision.sln          # Visual Studio solution




❓ How to Use
-Modify .aspx pages to customize UI.
-Update VB.NET code-behind files to add business logic.
-Set up your database by running the SQL script above.
-Connect your database string in Web.config.
-Build and run the project in Visual Studio.

if you have any query just dm me on insta - @waffbeen
and also feel free to use, modify, and extend this project for learning or production.

simple how you can use this - V
---

### How to use:

1. Save this content as `README.md` in your project root.  
2. Commit and push with:

```bash
git add README.md
git commit -m "Add complete README with SQL schema and usage"
git push

