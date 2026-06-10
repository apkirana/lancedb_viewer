<script>
	import { onMount } from 'svelte';

	// ── Database sources ───────────────────────────────────────────────────────
	const DATABASES = [
		{
			id: 'domain_knowledge',
			label: 'Domain Knowledge',
			icon: '📚',
			path: '/Users/puspa.kirana/Documents/GitHub/agentgip-paper1/database/domain_knowledge'
		},
		{
			id: 'episodic',
			label: 'Episodic',
			icon: '🧠',
			path: '/Users/puspa.kirana/Documents/GitHub/agentgip-paper1/database/episodic'
		}
	];

	// ── Core state ─────────────────────────────────────────────────────────────
	let activeDbId = DATABASES[0].id;
	let connectionCache = {};
	let tables = [];
	let selectedTable = '';
	let tableData = [];
	let loading = false;
	let error = '';
	let successMsg = '';

	// ── Pagination ─────────────────────────────────────────────────────────────
	let currentPage = 1;
	let perPage = 25;
	let hasMore = false;
	let totalRecords = 0;

	// ── Expanded cells ─────────────────────────────────────────────────────────
	let expandedCells = {};

	// ── CRUD modal ─────────────────────────────────────────────────────────────
	let showModal = false;
	let modalMode = 'add'; // 'add' | 'edit'
	let formFields = [];
	let formError = '';
	let formLoading = false;
	let formSuccess = '';

	// ── Delete dialog ──────────────────────────────────────────────────────────
	let showDeleteConfirm = false;
	let deletingRow = null;
	let deleteLoading = false;

	// ── Computed ───────────────────────────────────────────────────────────────
	$: activeDb = DATABASES.find(d => d.id === activeDbId);
	$: connectedCount = Object.values(connectionCache).filter(c => c.connected).length;

	$: displayColumns = tableData.length > 0
		? Object.keys(tableData[0]).filter(k => k !== '_rowid')
		: [];

	$: uniqueField = tableData.length > 0
		? (Object.keys(tableData[0]).find(k => k === 'id') ||
		   Object.keys(tableData[0]).find(k => k.endsWith('_id')) ||
		   Object.keys(tableData[0])[0])
		: 'id';

	$: editableKeys = tableData.length > 0
		? Object.keys(tableData[0]).filter(k => k !== '_rowid' && k !== 'vector')
		: [];

	// ── Helpers ────────────────────────────────────────────────────────────────
	function toggleCell(rowIndex, column) {
		const key = `${rowIndex}-${column}`;
		expandedCells = { ...expandedCells, [key]: !expandedCells[key] };
	}

	function getFieldType(val) {
		if (Array.isArray(val)) return 'array';
		if (typeof val === 'number') return 'number';
		if (typeof val === 'boolean') return 'boolean';
		if (typeof val === 'object' && val !== null) return 'json';
		return 'text';
	}

	function formatCellPreview(val, col) {
		if (col === 'vector') return `[float[${Array.isArray(val) ? val.length : '?'}]]`;
		if (val === null || val === undefined) return null;
		if (Array.isArray(val)) return `[array · ${val.length} items]`;
		if (typeof val === 'object') return JSON.stringify(val).substring(0, 80);
		const s = String(val);
		return s.length > 90 ? s.substring(0, 90) + '…' : s;
	}

	function showSuccess(msg) {
		successMsg = msg;
		setTimeout(() => successMsg = '', 3000);
	}

	// ── Connect ────────────────────────────────────────────────────────────────
	async function connectToDatabase(db) {
		if (connectionCache[db.id]?.connected) {
			tables = connectionCache[db.id].tables;
			selectedTable = '';
			tableData = [];
			return;
		}
		loading = true;
		error = '';
		tables = [];
		selectedTable = '';
		tableData = [];
		try {
			const res = await fetch('http://localhost:8001/api/connect/', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ provider: 'local', local_path: db.path })
			});
			if (res.ok) {
				const result = await res.json();
				connectionCache[db.id] = { connected: true, tables: result.tables };
				connectionCache = { ...connectionCache };
				tables = result.tables;
			} else {
				error = `Failed to connect to "${db.label}"`;
			}
		} catch (err) {
			error = `Connection error: ${err.message}`;
		} finally {
			loading = false;
		}
	}

	async function switchDatabase(dbId) {
		activeDbId = dbId;
		selectedTable = '';
		tableData = [];
		expandedCells = {};
		error = '';
		currentPage = 1;
		await connectToDatabase(DATABASES.find(d => d.id === dbId));
	}

	async function ensureConnected() {
		const db = DATABASES.find(d => d.id === activeDbId);
		const res = await fetch('http://localhost:8001/api/connect/', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ provider: 'local', local_path: db.path })
		});
		return res.ok;
	}

	// ── Fetch / paginate ───────────────────────────────────────────────────────
	async function loadTableData(tableName, page = 1) {
		selectedTable = tableName;
		currentPage = page;
		loading = true;
		error = '';
		tableData = [];
		expandedCells = {};
		try {
			if (!(await ensureConnected())) {
				error = 'Failed to connect to database'; loading = false; return;
			}
			const res = await fetch(
				`http://localhost:8001/api/fetch-data/${tableName}/?page=${page}&per_page=${perPage}`
			);
			if (res.ok) {
				const result = await res.json();
				tableData = result.data;
				hasMore = result.data.length === perPage;
				totalRecords = result.total_count ?? result.data.length;
			} else {
				error = `Error ${res.status}: ${await res.text()}`;
			}
		} catch (err) {
			error = 'Network error: ' + err.message;
		} finally {
			loading = false;
		}
	}

	async function changePage(delta) {
		const next = currentPage + delta;
		if (next < 1 || (!hasMore && delta > 0)) return;
		await loadTableData(selectedTable, next);
	}

	async function changePerPage(val) {
		perPage = Number(val);
		currentPage = 1;
		if (selectedTable) await loadTableData(selectedTable, 1);
	}

	// ── CRUD: Add ──────────────────────────────────────────────────────────────
	function openAddModal() {
		modalMode = 'add';
		formError = '';
		formSuccess = '';
		formFields = editableKeys.map(k => ({
			key: k,
			value: k === uniqueField ? crypto.randomUUID() : '',
			type: getFieldType(tableData[0]?.[k])
		}));
		showModal = true;
	}

	// ── CRUD: Edit ─────────────────────────────────────────────────────────────
	function openEditModal(row) {
		modalMode = 'edit';
		formError = '';
		formSuccess = '';
		formFields = editableKeys.map(k => ({
			key: k,
			value: typeof row[k] === 'object' && row[k] !== null
				? JSON.stringify(row[k], null, 2)
				: String(row[k] ?? ''),
			type: getFieldType(row[k])
		}));
		showModal = true;
	}

	async function submitForm() {
		formLoading = true;
		formError = '';
		formSuccess = '';
		try {
			if (!(await ensureConnected())) {
				formError = 'Failed to connect'; formLoading = false; return;
			}
			const record = {};
			for (const field of formFields) {
				if (field.type === 'number') {
					record[field.key] = Number(field.value);
				} else if (field.type === 'boolean') {
					record[field.key] = field.value === 'true';
				} else if (field.type === 'json' || field.type === 'array') {
					try { record[field.key] = JSON.parse(field.value); }
					catch { formError = `Invalid JSON in "${field.key}"`; formLoading = false; return; }
				} else {
					record[field.key] = field.value;
				}
			}

			const url = modalMode === 'add' ? '/api/add-data/' : '/api/update-data/';
			const body = modalMode === 'add'
				? { table: selectedTable, data: [record] }
				: { table: selectedTable, unique_field: uniqueField, data: [record] };

			const res = await fetch(`http://localhost:8001${url}`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify(body)
			});
			if (res.ok) {
				formSuccess = modalMode === 'add' ? 'Record added successfully!' : 'Record updated!';
				setTimeout(() => {
					showModal = false;
					loadTableData(selectedTable, currentPage);
					showSuccess(formSuccess);
				}, 700);
			} else {
				formError = `Error: ${await res.text()}`;
			}
		} catch (err) {
			formError = err.message;
		} finally {
			formLoading = false;
		}
	}

	// ── CRUD: Delete ───────────────────────────────────────────────────────────
	function confirmDeleteRow(row) {
		deletingRow = row;
		showDeleteConfirm = true;
	}

	async function executeDelete() {
		if (!deletingRow) return;
		deleteLoading = true;
		try {
			if (!(await ensureConnected())) { deleteLoading = false; return; }
			const val = deletingRow[uniqueField];
			const condition = typeof val === 'string'
				? `${uniqueField} = '${val}'`
				: `${uniqueField} = ${val}`;

			const res = await fetch('http://localhost:8001/api/delete-data/', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ table: selectedTable, condition })
			});
			if (res.ok) {
				showDeleteConfirm = false;
				deletingRow = null;
				// Go back a page if we deleted the last row on this page
				const prevPage = tableData.length === 1 && currentPage > 1 ? currentPage - 1 : currentPage;
				await loadTableData(selectedTable, prevPage);
				showSuccess('Record deleted.');
			} else {
				error = `Delete failed: ${await res.text()}`;
				showDeleteConfirm = false;
			}
		} catch (err) {
			error = err.message;
		} finally {
			deleteLoading = false;
		}
	}

	onMount(() => {
		connectionCache = {};
		connectToDatabase(DATABASES[0]);
	});
</script>

<!-- ─── Layout ─────────────────────────────────────────────────────────────── -->
<div class="min-h-screen flex flex-col bg-background text-foreground">

	<!-- Header -->
	<header class="h-12 border-b border-border flex items-center px-5 gap-3 shrink-0 bg-card/40 backdrop-blur-sm sticky top-0 z-30">
		<div class="flex items-center gap-2">
			<svg class="w-4 h-4 text-muted-foreground" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
				<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>
			</svg>
			<span class="text-sm font-semibold tracking-tight">LanceDB Viewer</span>
		</div>
		<div class="ml-auto flex items-center gap-2 text-xs text-muted-foreground">
			<span class="inline-flex items-center gap-1">
				<span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
				{connectedCount}/{DATABASES.length} connected
			</span>
		</div>
	</header>

	<div class="flex flex-1 overflow-hidden">

		<!-- Sidebar -->
		<aside class="w-56 border-r border-border bg-sidebar flex flex-col shrink-0 overflow-y-auto">

			<!-- Databases -->
			<div class="px-3 pt-4 pb-2">
				<p class="text-[10px] font-semibold uppercase tracking-widest text-muted-foreground px-1 mb-2">Databases</p>
				{#each DATABASES as db}
					<button
						class="w-full text-left px-2.5 py-1.5 rounded-md text-sm flex items-center gap-2 transition-colors mb-0.5"
						class:bg-secondary={activeDbId === db.id}
						class:text-foreground={activeDbId === db.id}
						class:font-medium={activeDbId === db.id}
						class:text-muted-foreground={activeDbId !== db.id}
						class:hover:bg-accent={activeDbId !== db.id}
						on:click={() => switchDatabase(db.id)}
						disabled={loading}
					>
						<span class="text-base leading-none">{db.icon}</span>
						<span class="truncate">{db.label}</span>
						{#if connectionCache[db.id]?.connected}
							<span class="ml-auto text-[10px] text-muted-foreground tabular-nums">
								{connectionCache[db.id].tables.length}
							</span>
						{/if}
					</button>
				{/each}
			</div>

			<!-- Tables -->
			{#if tables.length > 0}
				<div class="px-3 pt-3 pb-4 border-t border-border mt-1">
					<p class="text-[10px] font-semibold uppercase tracking-widest text-muted-foreground px-1 mb-2">Tables</p>
					{#each tables as table}
						<button
							class="w-full text-left px-2.5 py-1.5 rounded-md text-xs flex items-center gap-2 transition-colors mb-0.5 truncate"
							class:bg-accent={selectedTable === table}
							class:text-foreground={selectedTable === table}
							class:font-medium={selectedTable === table}
							class:text-muted-foreground={selectedTable !== table}
							class:hover:bg-accent={selectedTable !== table}
							class:hover:text-foreground={selectedTable !== table}
							on:click={() => { currentPage = 1; loadTableData(table, 1); }}
							disabled={loading}
							title={table}
						>
							<svg class="w-3 h-3 shrink-0 opacity-50" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
								<path d="M3 3h18v5H3zM3 11h18v5H3zM3 19h18v2H3z"/>
							</svg>
							<span class="truncate">{table}</span>
						</button>
					{/each}
				</div>
			{/if}

			<!-- Loading sidebar -->
			{#if loading && tables.length === 0}
				<div class="px-4 py-6 flex items-center gap-2 text-xs text-muted-foreground">
					<svg class="w-3 h-3 animate-spin shrink-0" viewBox="0 0 24 24" fill="none">
						<circle class="opacity-20" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
						<path class="opacity-70" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"/>
					</svg>
					Connecting…
				</div>
			{/if}
		</aside>

		<!-- Main -->
		<main class="flex-1 flex flex-col overflow-hidden">

			<!-- Toast success -->
			{#if successMsg}
				<div class="fixed bottom-4 right-4 z-50 bg-foreground text-background text-sm px-4 py-2.5 rounded-lg shadow-xl flex items-center gap-2">
					<svg class="w-4 h-4 text-emerald-600" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg>
					{successMsg}
				</div>
			{/if}

			<!-- Error banner -->
			{#if error}
				<div class="mx-4 mt-4 bg-destructive/10 border border-destructive/40 text-sm px-4 py-2.5 rounded-lg flex items-start gap-2">
					<svg class="w-4 h-4 text-destructive shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/></svg>
					<span class="text-foreground">{error}</span>
					<button class="ml-auto text-muted-foreground hover:text-foreground" on:click={() => error = ''}>✕</button>
				</div>
			{/if}

			<!-- Empty state: no table selected -->
			{#if !selectedTable && !loading}
				<div class="flex-1 flex flex-col items-center justify-center text-center p-8 gap-3">
					<div class="w-12 h-12 rounded-xl bg-secondary flex items-center justify-center">
						<svg class="w-6 h-6 text-muted-foreground" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
							<path d="M3 3h18v5H3zM3 11h18v5H3zM3 19h18v2H3z"/>
						</svg>
					</div>
					<p class="font-medium text-sm">Select a table to view data</p>
					<p class="text-xs text-muted-foreground max-w-xs">
						Choose a database and table from the sidebar to browse, search, and edit records.
					</p>
				</div>
			{/if}

			<!-- Loading -->
			{#if loading && selectedTable}
				<div class="flex items-center gap-2 px-5 py-4 text-sm text-muted-foreground">
					<svg class="w-4 h-4 animate-spin" viewBox="0 0 24 24" fill="none">
						<circle class="opacity-20" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
						<path class="opacity-70" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"/>
					</svg>
					Loading <strong class="text-foreground">{selectedTable}</strong>…
				</div>
			{/if}

			<!-- Table view -->
			{#if selectedTable && !loading}

				<!-- Toolbar -->
				<div class="flex items-center gap-3 px-5 py-3 border-b border-border shrink-0">
					<div>
						<h2 class="text-sm font-semibold text-foreground leading-none">{selectedTable}</h2>
						<p class="text-[11px] text-muted-foreground mt-0.5">
							{activeDb?.label} · <strong class="text-foreground">{totalRecords.toLocaleString()}</strong> records total
						</p>
					</div>

					<div class="ml-auto flex items-center gap-2">
						<!-- Per page -->
						<select
							class="h-7 text-xs bg-secondary border border-border rounded-md px-2 text-foreground cursor-pointer"
							value={perPage}
							on:change={e => changePerPage(e.target.value)}
						>
							<option value="10">10 / page</option>
							<option value="25">25 / page</option>
							<option value="50">50 / page</option>
							<option value="100">100 / page</option>
						</select>

						<!-- Add button -->
						{#if tableData.length > 0}
							<button
								class="h-7 px-3 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors flex items-center gap-1.5"
								on:click={openAddModal}
							>
								<svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>
								Add Record
							</button>
						{/if}
					</div>
				</div>

				<!-- Table -->
				{#if tableData.length > 0}
					<div class="flex-1 overflow-auto">
						<div class="min-w-max">
						<table class="w-full text-xs border-collapse">
							<thead class="sticky top-0 z-10">
								<tr class="bg-card border-b border-border">
									{#each displayColumns as col}
										<th class="px-4 py-2.5 text-left font-medium text-muted-foreground whitespace-nowrap border-r border-border last:border-r-0 tracking-wide text-[11px] uppercase">
											{col}
										</th>
									{/each}
									<!-- Actions column -->
									<th class="px-4 py-2.5 text-right font-medium text-muted-foreground whitespace-nowrap tracking-wide text-[11px] uppercase sticky right-0 bg-card">
										Actions
									</th>
								</tr>
							</thead>
							<tbody>
								{#each tableData as row, i}
									<tr class="border-b border-border hover:bg-accent/40 transition-colors group {i % 2 === 0 ? 'bg-background' : 'bg-card/30'}">
										{#each displayColumns as col}
											<!-- svelte-ignore a11y-click-events-have-key-events -->
											<!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
											<td
												class="px-4 py-2.5 border-r border-border last:border-r-0 align-top max-w-xs cursor-pointer"
												on:click={() => toggleCell(i, col)}
											>
												{#if col === 'vector'}
													<span class="inline-flex items-center gap-1 text-muted-foreground font-mono text-[10px] bg-secondary px-1.5 py-0.5 rounded">
														float[{Array.isArray(row[col]) ? row[col].length : '?'}]
													</span>
												{:else if row[col] === null || row[col] === undefined}
													<span class="text-muted-foreground/50 italic">—</span>
												{:else if expandedCells[`${i}-${col}`]}
													<div class="font-mono text-[10px] whitespace-pre-wrap break-all bg-secondary p-2 rounded border border-border max-w-sm">
														{typeof row[col] === 'object' ? JSON.stringify(row[col], null, 2) : String(row[col])}
													</div>
												{:else}
													<span
														class="block truncate max-w-[220px] {typeof row[col] === 'object' ? 'text-muted-foreground font-mono text-[10px]' : 'text-foreground'}"
														title="Click to expand"
													>
														{formatCellPreview(row[col], col)}
													</span>
												{/if}
											</td>
										{/each}

										<!-- Row actions -->
										<td class="px-3 py-2 text-right whitespace-nowrap sticky right-0 bg-inherit">
											<div class="flex items-center justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
												<button
													class="h-6 w-6 flex items-center justify-center rounded text-muted-foreground hover:text-foreground hover:bg-secondary transition-colors"
													title="Edit"
													on:click|stopPropagation={() => openEditModal(row)}
												>
													<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
														<path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
													</svg>
												</button>
												<button
													class="h-6 w-6 flex items-center justify-center rounded text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
													title="Delete"
													on:click|stopPropagation={() => confirmDeleteRow(row)}
												>
													<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
														<polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4h6v2"/>
													</svg>
												</button>
											</div>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
						</div>
					</div>

					<!-- Pagination footer -->
					<div class="flex items-center justify-between px-5 py-3 border-t border-border shrink-0 bg-card/30">
						<span class="text-xs text-muted-foreground">
							Showing
							<strong class="text-foreground tabular-nums">{((currentPage - 1) * perPage + 1).toLocaleString()}</strong>–<strong class="text-foreground tabular-nums">{Math.min(currentPage * perPage, totalRecords).toLocaleString()}</strong>
							of <strong class="text-foreground tabular-nums">{totalRecords.toLocaleString()}</strong> records
						</span>
						<div class="flex items-center gap-1">
							<button
								class="h-7 px-3 text-xs rounded-md border border-border bg-secondary hover:bg-accent transition-colors disabled:opacity-30 disabled:cursor-not-allowed flex items-center gap-1"
								disabled={currentPage <= 1}
								on:click={() => changePage(-1)}
							>
								<svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M15 18l-6-6 6-6"/></svg>
								Prev
							</button>
							<span class="h-7 px-3 text-xs flex items-center text-foreground font-medium bg-secondary border border-border rounded-md tabular-nums">
								{currentPage}
							</span>
							<button
								class="h-7 px-3 text-xs rounded-md border border-border bg-secondary hover:bg-accent transition-colors disabled:opacity-30 disabled:cursor-not-allowed flex items-center gap-1"
								disabled={!hasMore}
								on:click={() => changePage(1)}
							>
								Next
								<svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 18l6-6-6-6"/></svg>
							</button>
						</div>
					</div>

				{:else if !loading}
					<!-- Empty table -->
					<div class="flex-1 flex flex-col items-center justify-center p-8 gap-2 text-center">
						<svg class="w-8 h-8 text-muted-foreground/40" fill="none" stroke="currentColor" stroke-width="1" viewBox="0 0 24 24">
							<path d="M3 3h18v5H3zM3 11h18v5H3zM3 19h18v2H3z"/>
						</svg>
						<p class="text-sm text-muted-foreground">No records in <strong class="text-foreground">{selectedTable}</strong></p>
						<button
							class="mt-2 h-7 px-3 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90"
							on:click={openAddModal}
						>
							Add first record
						</button>
					</div>
				{/if}
			{/if}
		</main>
	</div>
</div>

<!-- ─── Add / Edit Modal ───────────────────────────────────────────────────── -->
{#if showModal}
	<!-- Backdrop -->
	<div
		class="fixed inset-0 z-40 bg-black/70 backdrop-blur-sm"
		on:click={() => showModal = false}
		role="dialog"
		aria-modal="true"
	></div>

	<!-- Panel -->
	<div class="fixed inset-0 z-50 flex items-center justify-center p-4 pointer-events-none">
		<div class="bg-card border border-border rounded-xl shadow-2xl w-full max-w-lg max-h-[85vh] flex flex-col pointer-events-auto">

			<!-- Modal header -->
			<div class="flex items-center px-5 py-4 border-b border-border shrink-0">
				<h3 class="text-sm font-semibold">
					{modalMode === 'add' ? 'Add Record' : 'Edit Record'}
					<span class="ml-2 text-xs font-normal text-muted-foreground">→ {selectedTable}</span>
				</h3>
				<button class="ml-auto text-muted-foreground hover:text-foreground transition-colors" on:click={() => showModal = false}>
					<svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M18 6L6 18M6 6l12 12"/></svg>
				</button>
			</div>

			<!-- Modal body -->
			<div class="overflow-y-auto flex-1 px-5 py-4 space-y-3">
				{#if formError}
					<div class="text-xs text-destructive bg-destructive/10 border border-destructive/30 px-3 py-2 rounded-lg">{formError}</div>
				{/if}
				{#if formSuccess}
					<div class="text-xs text-emerald-400 bg-emerald-400/10 border border-emerald-400/30 px-3 py-2 rounded-lg flex items-center gap-1.5">
						<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg>
						{formSuccess}
					</div>
				{/if}

				{#each formFields as field}
					<div class="space-y-1">
						<label class="text-[11px] font-medium text-muted-foreground uppercase tracking-wide flex items-center gap-1.5">
							{field.key}
							{#if field.key === uniqueField}
								<span class="text-[9px] bg-secondary px-1.5 py-0.5 rounded text-muted-foreground">unique</span>
							{/if}
							{#if field.type !== 'text' && field.type !== 'number'}
								<span class="text-[9px] bg-secondary px-1.5 py-0.5 rounded text-muted-foreground">{field.type}</span>
							{/if}
						</label>

						{#if field.type === 'json' || field.type === 'array'}
							<textarea
								class="w-full bg-input border border-border rounded-md px-3 py-2 text-[11px] font-mono text-foreground resize-y min-h-[80px] focus:outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground"
								bind:value={field.value}
								placeholder="JSON value…"
								disabled={formLoading}
							></textarea>
						{:else if field.type === 'boolean'}
							<select
								class="w-full h-8 bg-input border border-border rounded-md px-3 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-ring"
								bind:value={field.value}
								disabled={formLoading}
							>
								<option value="true">true</option>
								<option value="false">false</option>
							</select>
						{:else}
							<input
								class="w-full h-8 bg-input border border-border rounded-md px-3 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground font-mono"
								type={field.type === 'number' ? 'number' : 'text'}
								bind:value={field.value}
								disabled={formLoading || (modalMode === 'edit' && field.key === uniqueField)}
								placeholder={field.key}
							/>
						{/if}
					</div>
				{/each}
			</div>

			<!-- Modal footer -->
			<div class="flex items-center justify-end gap-2 px-5 py-4 border-t border-border shrink-0">
				<button
					class="h-8 px-4 text-xs rounded-md border border-border text-muted-foreground hover:text-foreground hover:bg-accent transition-colors"
					on:click={() => showModal = false}
					disabled={formLoading}
				>
					Cancel
				</button>
				<button
					class="h-8 px-4 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors disabled:opacity-50 flex items-center gap-1.5"
					on:click={submitForm}
					disabled={formLoading}
				>
					{#if formLoading}
						<svg class="w-3 h-3 animate-spin" viewBox="0 0 24 24" fill="none">
							<circle class="opacity-20" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
							<path class="opacity-70" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"/>
						</svg>
					{/if}
					{modalMode === 'add' ? 'Add Record' : 'Save Changes'}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- ─── Delete Confirmation ────────────────────────────────────────────────── -->
{#if showDeleteConfirm}
	<div
		class="fixed inset-0 z-40 bg-black/70 backdrop-blur-sm"
		on:click={() => showDeleteConfirm = false}
		role="dialog"
		aria-modal="true"
	></div>

	<div class="fixed inset-0 z-50 flex items-center justify-center p-4 pointer-events-none">
		<div class="bg-card border border-border rounded-xl shadow-2xl w-full max-w-sm pointer-events-auto">
			<div class="px-5 py-4">
				<div class="flex items-start gap-3">
					<div class="w-8 h-8 rounded-lg bg-destructive/15 flex items-center justify-center shrink-0">
						<svg class="w-4 h-4 text-destructive" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
							<polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M9 6V4h6v2"/>
						</svg>
					</div>
					<div>
						<h3 class="text-sm font-semibold">Delete Record</h3>
						<p class="text-xs text-muted-foreground mt-1">
							This will permanently delete the record where
							<code class="font-mono text-[10px] bg-secondary px-1 py-0.5 rounded">{uniqueField}</code>
							=
							<code class="font-mono text-[10px] bg-secondary px-1 py-0.5 rounded">{deletingRow?.[uniqueField]}</code>.
							This action cannot be undone.
						</p>
					</div>
				</div>

				<div class="flex items-center justify-end gap-2 mt-4">
					<button
						class="h-8 px-4 text-xs rounded-md border border-border text-muted-foreground hover:text-foreground hover:bg-accent transition-colors"
						on:click={() => showDeleteConfirm = false}
						disabled={deleteLoading}
					>
						Cancel
					</button>
					<button
						class="h-8 px-4 text-xs font-medium bg-destructive text-white rounded-md hover:bg-destructive/90 transition-colors disabled:opacity-50 flex items-center gap-1.5"
						on:click={executeDelete}
						disabled={deleteLoading}
					>
						{#if deleteLoading}
							<svg class="w-3 h-3 animate-spin" viewBox="0 0 24 24" fill="none">
								<circle class="opacity-20" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
								<path class="opacity-70" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"/>
							</svg>
						{/if}
						Delete
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}
