<script>
	import { onMount } from 'svelte';
	
	let tables = ['agentgip_kb_agents', 'agentgip_kb_crs', 'agentgip_kb_domain', 'agentgip_kb_operations', 'agentgip_kb_rules'];
	let selectedTable = '';
	let tableData = [];
	let loading = false;
	let error = '';
	
	async function loadTableData(tableName) {
		console.log('Loading table:', tableName);
		selectedTable = tableName;
		loading = true;
		error = '';
		
		try {
			const response = await fetch(`http://localhost:8001/api/fetch-data/${tableName}/?page=1&per_page=5`);
			console.log('Response status:', response.status);
			
			if (response.ok) {
				const result = await response.json();
				console.log('Data received:', result);
				tableData = result.data;
			} else {
				const errorText = await response.text();
				error = `Error: ${response.status} - ${errorText}`;
				console.error('Error:', response.status, errorText);
			}
		} catch (err) {
			error = 'Network error: ' + err.message;
			console.error('Network error:', err);
		} finally {
			loading = false;
		}
	}
	
	onMount(() => {
		console.log('Simple test page mounted');
	});
</script>

<div class="p-8">
	<h1 class="text-2xl font-bold mb-4">Simple LanceDB Test</h1>
	
	<div class="mb-4">
		<h2 class="text-lg font-semibold mb-2">Click a table to load data:</h2>
		{#each tables as table}
			<button 
				class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 mr-2 mb-2 rounded"
				on:click={() => loadTableData(table)}
				disabled={loading}
			>
				{table}
			</button>
		{/each}
	</div>
	
	{#if loading}
		<div class="text-center py-4">
			<p>Loading...</p>
		</div>
	{/if}
	
	{#if error}
		<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
			{error}
		</div>
	{/if}
	
	{#if selectedTable}
		<div class="mb-4">
			<h3 class="text-lg font-semibold">Selected: {selectedTable}</h3>
			<p>Records found: {tableData.length}</p>
		</div>
		
		{#if tableData.length > 0}
			<div class="border border-gray-300 rounded">
				<table class="w-full">
					<thead>
						<tr class="bg-gray-100">
							{#each Object.keys(tableData[0]) as column}
								<th class="border border-gray-300 px-4 py-2 text-left">{column}</th>
							{/each}
						</tr>
					</thead>
					<tbody>
						{#each tableData as row, i}
							<tr class="{i % 2 === 0 ? 'bg-white' : 'bg-gray-50'}">
								{#each Object.keys(tableData[0]) as column}
									<td class="border border-gray-300 px-4 py-2 text-sm">
										{#if typeof row[column] === 'object'}
											JSON.stringify(row[column]).substring(0, 100)...
										{:else}
											{String(row[column]).substring(0, 100)}
											{#if String(row[column]).length > 100}...{/if}
										{/if}
									</td>
								{/each}
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	{/if}
</div>
