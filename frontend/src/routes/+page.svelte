<script>
	import { onMount } from 'svelte';
	
	let tables = ['agentgip_kb_agents', 'agentgip_kb_crs', 'agentgip_kb_domain', 'agentgip_kb_operations', 'agentgip_kb_rules'];
	let selectedTable = '';
	let tableData = [];
	let loading = false;
	let error = '';
	let connected = false;
	
	async function connectToDatabase() {
		console.log('Connecting to database...');
		loading = true;
		error = '';
		
		try {
			const response = await fetch('http://localhost:8001/api/connect/', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({ 
					provider: "local",
					local_path: "/Users/puspa.kirana/Documents/GitHub/lancedb_viewer/lancedb-viewer/backend/lancedb_data"
				})
			});
			
			if (response.ok) {
				const result = await response.json();
				console.log('Connected:', result);
				connected = true;
				tables = result.tables;
			} else {
				error = 'Failed to connect to database';
			}
		} catch (err) {
			error = 'Connection error: ' + err.message;
		} finally {
			loading = false;
		}
	}
	
	async function loadTableData(tableName) {
		console.log('Loading table:', tableName);
		selectedTable = tableName;
		loading = true;
		error = '';
		
		try {
			const response = await fetch(`http://localhost:8001/api/fetch-data/${tableName}/?page=1&per_page=10`);
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
		connectToDatabase();
	});
</script>

<div class="p-8 max-w-6xl mx-auto">
	<h1 class="text-3xl font-bold mb-8 text-center">LanceDB Viewer</h1>
	
	{#if loading && !connected}
		<div class="text-center py-8">
			<p class="text-lg">Connecting to database...</p>
		</div>
	{/if}
	
	{#if error}
		<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6">
			<strong>Error:</strong> {error}
		</div>
	{/if}
	
	{#if connected}
		<div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-6">
			<strong>✅ Connected!</strong> Found {tables.length} tables in your database
		</div>
		
		<div class="mb-8">
			<h2 class="text-xl font-semibold mb-4">Click a table to view data:</h2>
			<div class="flex flex-wrap gap-2">
				{#each tables as table}
					<button 
						class="bg-blue-500 hover:bg-blue-600 text-white font-medium py-2 px-4 rounded transition-colors"
						class:bg-green-500={selectedTable === table}
						class:hover:bg-green-600={selectedTable === table}
						on:click={() => loadTableData(table)}
						disabled={loading}
					>
						{table}
					</button>
				{/each}
			</div>
		</div>
	{/if}
	
	{#if selectedTable && loading}
		<div class="text-center py-8">
			<p class="text-lg">Loading data from {selectedTable}...</p>
		</div>
	{/if}
	
	{#if selectedTable && tableData.length > 0}
		<div class="mb-6">
			<h3 class="text-xl font-semibold mb-2">
				📊 {selectedTable} 
				<span class="text-sm text-gray-600 font-normal">({tableData.length} records)</span>
			</h3>
		</div>
		
		<div class="overflow-x-auto border border-gray-300 rounded-lg">
			<table class="w-full">
				<thead>
					<tr class="bg-gray-100">
						{#each Object.keys(tableData[0]) as column}
							<th class="border border-gray-300 px-4 py-3 text-left font-semibold text-sm">
								{column}
							</th>
						{/each}
					</tr>
				</thead>
				<tbody>
					{#each tableData as row, i}
						<tr class="{i % 2 === 0 ? 'bg-white' : 'bg-gray-50'} hover:bg-blue-50">
							{#each Object.keys(tableData[0]) as column}
								<td class="border border-gray-300 px-4 py-3 text-sm">
									{#if typeof row[column] === 'object' && row[column] !== null}
										<div class="max-w-xs truncate" title={JSON.stringify(row[column])}>
											{JSON.stringify(row[column]).substring(0, 100)}
											{#if JSON.stringify(row[column]).length > 100}...{/if}
										</div>
									{:else if row[column] === null || row[column] === undefined}
										<span class="text-gray-400 italic">null</span>
									{:else}
										<div class="max-w-xs truncate" title={String(row[column])}>
											{String(row[column]).substring(0, 100)}
											{#if String(row[column]).length > 100}...{/if}
										</div>
									{/if}
								</td>
							{/each}
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
		
		<div class="mt-4 text-sm text-gray-600">
			💡 <strong>Tip:</strong> Hover over truncated cells to see full content in tooltip
		</div>
	{:else if selectedTable && !loading}
		<div class="text-center py-8 bg-yellow-50 border border-yellow-200 rounded">
			<p class="text-lg">📭 No data found in {selectedTable}</p>
		</div>
	{/if}
</div>

<style>
	:global(body) {
		background: #f8fafc;
	}
</style>
