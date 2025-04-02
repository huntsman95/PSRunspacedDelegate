class RunspacedDelegateFactory {
    static [System.Delegate] NewRunspacedDelegate ([System.Delegate]$_delegate, [runspace]$runspace) {
        $runspaceConstant = [System.Linq.Expressions.Expression]::Constant($runspace)
        $runspaceProperty = [System.Linq.Expressions.Expression]::Property(
            $null,
            [System.Management.Automation.Runspaces.Runspace].GetProperty('DefaultRunspace')
        )
        $assignExpression = [System.Linq.Expressions.Expression]::Assign(
            $runspaceProperty,
            $runspaceConstant
        )
        $setRunspaceExpression = [System.Linq.Expressions.Expression]::Lambda(
            [System.Action],
            $assignExpression
        )
        $setRunspace = $setRunspaceExpression.Compile()
        return [RunspacedDelegateFactory]::ConcatActionToDelegate($setRunspace, $_delegate)
    }
    
    static [System.Linq.Expressions.Expression] ExpressionInvoke ([System.Delegate]$_delegate, $arguments) {
        $invokeMethod = $_delegate.GetType().GetMethod('Invoke')
        return [System.Linq.Expressions.Expression]::Call([System.Linq.Expressions.Expression]::Constant($_delegate), $invokeMethod, $arguments)
    }

    static [System.Delegate] ConcatActionToDelegate([System.Action]$a, [System.Delegate]$d) {
        $parameters = [Linq.Enumerable]::ToArray(
            [Linq.Enumerable]::Select(
                ($d.GetType().GetMethod('Invoke').GetParameters()),
                [Func[System.Object, System.Object]] { param($p) [System.Linq.Expressions.Expression]::Parameter( $p.ParameterType, $p.Name ) }
            )
        )

        [System.Linq.Expressions.Expression] $body = [System.Linq.Expressions.Expression]::Block(
            [System.Linq.Expressions.Expression]::Invoke([System.Linq.Expressions.Expression]::Constant($a)),
            [System.Linq.Expressions.Expression]::Invoke([System.Linq.Expressions.Expression]::Constant($d), $parameters)
        )

        $lambda = [System.Linq.Expressions.Expression]::Lambda($d.GetType(), $body, '', $parameters)

        $compiled = $lambda.Compile()

        return $compiled
    }
}

Function New-RunspacedDelegate {
    param([Parameter(Mandatory=$true)][System.Delegate]$Delegate, [Runspace]$Runspace=[Runspace]::DefaultRunspace)

    [RunspacedDelegateFactory]::NewRunspacedDelegate($Delegate, $Runspace);
}