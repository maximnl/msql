
/****** Object:  StoredProcedure [dbo].[A_SP_SYS_INDEX_OPTÌMIZE]    Script Date: 27-10-2021 13:06:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		PLANSIS
-- Create date: 2020-01-01
-- Description:	Optimise indexes fragmenation
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[A_SP_SYS_INDEX_OPTÌMIZE]  AS
BEGIN
-- USE master
EXECUTE master.dbo.IndexOptimize
@Databases = 'Databasename',
@FragmentationLow = NULL,
@FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
@FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
@FragmentationLevel1 = 5,
@FragmentationLevel2 = 30,
@UpdateStatistics = 'ALL',
@OnlyModifiedStatistics = 'Y'

END
