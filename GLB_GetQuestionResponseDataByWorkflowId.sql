USE [PMGCustomData]
GO

/****** Object:  StoredProcedure [dbo].[GLB_GetQuestionResponseDataByWorkflowId]    Script Date: 10/24/2017 10:08:53 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Felipe A. Archila
-- Create date:	April 18, 2017
-- Last update:	May 23, 2017
-- Change Log:	5/23/17 (FA) Made updates to proc to return questions in correct index based on RequestData and exclude backend and hidden questions.
--					Also added support for passing in option parameters to exclude certain questions and add a leading carriage return before certain
--					questions.
-- Description:	Stored procedure to retrieve simply formatted question response data
--				for use in XML iterator formatter.
-- Input:		WorkflowId INT (should be workflow or execution id of the request you want question data for)
-- Input (opt):	ExcludedQuestionsSPENames NVARCHAR(MAX)
--				(a comma-separated list of SPE Mapping Names of questions you don't want returned)
-- Input (opt): AddSpaceBeforeQuestionsSPENames NVARCHAR(MAX)
--				(a comma-separated list of SPE Mapping Names of questions for which you want to add a leading carriage return e.g. to separate sections)
-- Output:		XML of all question data with the schema <root><row><question /><response /></row></root>
-- =============================================
CREATE PROCEDURE [dbo].[GLB_GetQuestionResponseDataByWorkflowId] 
	-- Add the parameters for the stored procedure here
	@WorkflowId INT,
	@ExcludedQuestionsSPENames NVARCHAR(MAX) = NULL,
	@AddSpaceBeforeQuestionsSPENames NVARCHAR(MAX) = NULL

AS
BEGIN

	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb..#temp_questionFormat') IS NOT NULL
	BEGIN
		DROP TABLE #temp_questionFormat
	END

	;WITH VisibleQuestions
	AS
	(
		SELECT A.value('(./@index)[1]','int') [qindex], A.value('(./display_name)[1]','nvarchar(max)') [question], A.value('(./@adv_invisible)[1]', 'int') [invisible]
		FROM
		(
			SELECT
			convert(xml, question_response_xml) [QR]
			FROM PMGSPE..SC_RequestData
			where execution_id = @WorkflowId
		)z CROSS APPLY QR.nodes('/form_elements//form_element[not(@adv_invisible)]') AS Q(A)
	)

	SELECT * INTO #temp_questionFormat
	FROM

	(
	SELECT ROW_NUMBER() OVER (PARTITION BY RQD.question ORDER BY [index] asc) [row_num]
	, VQ.qindex
	, RQD.question
	, RQD.id
	, CASE WHEN RQD.field_name_display IS NULL THEN
		CASE WHEN RIGHT(RQD.question_display_name, 1) IN ('?',':') THEN RQD.question_display_name ELSE RQD.question_display_name + ':' END
	  WHEN RQD.question_display_name = RQD.field_name_display THEN RQD.field_name_display + ':'
	  ELSE RQD.question_display_name + ': ' + RQD.field_name_display + ':' END AS [question_display_name]
	, CASE WHEN RQD.response_display IS NULL THEN RQD.response ELSE RQD.response_display END AS [response_display]
	FROM PMGSPE..SC_RequestData RD WITH(NOLOCK)
	INNER JOIN PMGSPE..SC_RequestQuestionData RQD WITH(NOLOCK)
		ON RQD.request_data_id = RD.Id
	INNER JOIN VisibleQuestions VQ
		ON VQ.question = RQD.question
	WHERE RD.execution_id = [PMGSPE].[dbo].[udf_GetTopParentExecutionId2_WF2](@WorkflowId)
	AND RQD.Historical = 0
	AND ((RQD.field_name_display IS NULL AND RQD.response <> '') OR (RQD.field_name_display IS NOT NULL))
	AND RQD.location = 0
	) Z

	UPDATE tQF1
	SET question = '!DELETEME!'
	FROM #temp_questionFormat tQF1
	INNER JOIN #temp_questionFormat tQF2
		ON tQF1.question = tQF2.question AND tQF2.row_num > 1
	WHERE tQF1.row_num = 1

	DELETE FROM #temp_questionFormat
	WHERE question = '!DELETEME!'

	IF @ExcludedQuestionsSPENames IS NOT NULL
	BEGIN
		DELETE FROM #temp_questionFormat
		WHERE question IN (SELECT LTRIM(RTRIM([data])) FROM PMGEMDB..fnSplitString(@ExcludedQuestionsSPENames, ','))
	END

	IF @AddSpaceBeforeQuestionsSPENames IS NOT NULL
	BEGIN
		INSERT INTO #temp_questionFormat

		SELECT 0, qindex, '', 0, '', ''
		FROM #temp_questionFormat
		WHERE question IN (SELECT LTRIM(RTRIM([data])) FROM PMGEMDB..fnSplitString(@AddSpaceBeforeQuestionsSPENames, ','))
	END

	SELECT(
	SELECT question_display_name [question], response_display [response]
	FROM #temp_questionFormat
	ORDER BY qindex, id
	FOR XML PATH('row'), TYPE, ELEMENTS XSINIL
	)
	FOR XML PATH(''), ELEMENTS XSINIL, ROOT('root')

	DROP TABLE #temp_questionFormat

END



GO


